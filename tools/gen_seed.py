"""Generates assets/data/seed_foods.json from a compact table.

Columns: name, kcal, protein, carbs, sugar, fat, satFat, fibre, sodium_mg,
         gi (None where the food has too little carb for GI to mean anything),
         nova, added_sugar (None = unknown/zero for whole foods), alcohol_g,
         grams_per_piece, piece_name

All values are per 100 g (or 100 ml for liquids).
"""
import json
import os

F = [
    # ---- grains & starches ----
    ("Oats, rolled, dry",        379, 13.2, 67.7, 1.0,  6.5, 1.2, 10.1,   6,  55, 1, None, 0, None, None),
    ("White rice, cooked",       130,  2.7, 28.0, 0.05, 0.3, 0.08, 0.4,   1,  73, 1, None, 0, None, None),
    ("Brown rice, cooked",       123,  2.7, 26.0, 0.4,  1.0, 0.2,  1.6,   4,  68, 1, None, 0, None, None),
    ("Pasta, dry",               371, 13.0, 75.0, 2.7,  1.5, 0.3,  3.2,   6,  49, 1, None, 0, None, None),
    ("Pasta, cooked",            158,  5.8, 31.0, 0.6,  0.9, 0.2,  1.8,   1,  49, 1, None, 0, None, None),
    ("Bread, white",             265,  9.0, 49.0, 5.0,  3.2, 0.7,  2.7, 490,  75, 3,  3.0, 0,   30, "slice"),
    ("Bread, wholemeal",         247, 13.0, 41.0, 4.3,  3.4, 0.7,  7.0, 450,  74, 3,  2.5, 0,   32, "slice"),
    ("Rye bread",                259,  8.5, 48.0, 3.9,  3.3, 0.6,  5.8, 603,  50, 3,  2.0, 0,   32, "slice"),
    ("Sourdough bread",          256,  8.7, 51.0, 2.2,  1.7, 0.4,  2.4, 490,  54, 3,  1.0, 0,   40, "slice"),
    ("Potato, boiled",            87,  1.9, 20.0, 0.9,  0.1, 0.03, 1.8,   4,  78, 1, None, 0, None, None),
    ("Potato, baked",             93,  2.5, 21.0, 1.2,  0.1, 0.03, 2.2,  10,  85, 1, None, 0, None, None),
    ("Sweet potato, boiled",      76,  1.4, 17.7, 5.7,  0.1, 0.03, 2.5,  27,  63, 1, None, 0, None, None),
    ("Quinoa, cooked",           120,  4.4, 21.3, 0.9,  1.9, 0.2,  2.8,   7,  53, 1, None, 0, None, None),
    ("Buckwheat, cooked",         92,  3.4, 19.9, 0.9,  0.6, 0.1,  2.7,   4,  45, 1, None, 0, None, None),
    ("Couscous, cooked",         112,  3.8, 23.2, 0.1,  0.2, 0.03, 1.4,   5,  65, 1, None, 0, None, None),
    ("Cornflakes",               357,  7.5, 84.0, 8.0,  0.4, 0.1,  3.3, 729,  81, 4,  8.0, 0, None, None),
    ("Muesli",                   363,  9.7, 66.0, 16.0, 5.9, 1.1,  7.4, 180,  57, 3, 10.0, 0, None, None),
    ("Tortilla, wheat",          312,  8.2, 51.0, 2.5,  7.9, 2.0,  3.0, 580,  52, 4,  1.5, 0,   45, "tortilla"),

    # ---- legumes ----
    ("Red lentils, dry",         352, 24.6, 63.0, 2.0,  1.1, 0.2, 10.7,   6,  32, 1, None, 0, None, None),
    ("Lentils, cooked",          116,  9.0, 20.0, 1.8,  0.4, 0.05, 7.9,   2,  32, 1, None, 0, None, None),
    ("Chickpeas, cooked",        164,  8.9, 27.4, 4.8,  2.6, 0.3,  7.6,   7,  28, 1, None, 0, None, None),
    ("Black beans, cooked",      132,  8.9, 23.7, 0.3,  0.5, 0.1,  8.7,   1,  30, 1, None, 0, None, None),
    ("Kidney beans, cooked",     127,  8.7, 22.8, 0.3,  0.5, 0.07, 6.4,   1,  24, 1, None, 0, None, None),
    ("Green peas, cooked",        84,  5.4, 15.6, 5.9,  0.2, 0.04, 5.5,   3,  51, 1, None, 0, None, None),
    ("Tofu, firm",               144, 17.3,  2.8, 0.6,  8.7, 1.3,  2.3,  14,  15, 3, None, 0, None, None),
    ("Soy beans, cooked",        173, 16.6,  9.9, 3.0,  9.0, 1.3,  6.0,   1,  16, 1, None, 0, None, None),
    ("Hummus",                   166,  7.9, 14.3, 0.3,  9.6, 1.4,  6.0, 379,   6, 3, None, 0, None, None),

    # ---- vegetables ----
    ("Broccoli, raw",             34,  2.8,  6.6, 1.7,  0.4, 0.04, 2.6,  33, None, 1, None, 0, None, None),
    ("Spinach, raw",              23,  2.9,  3.6, 0.4,  0.4, 0.06, 2.2,  79, None, 1, None, 0, None, None),
    ("Carrot, raw",               41,  0.9,  9.6, 4.7,  0.2, 0.03, 2.8,  69,  39, 1, None, 0,   61, "carrot"),
    ("Tomato",                    18,  0.9,  3.9, 2.6,  0.2, 0.03, 1.2,   5,  30, 1, None, 0,  123, "tomato"),
    ("Cucumber",                  15,  0.7,  3.6, 1.7,  0.1, 0.04, 0.5,   2, None, 1, None, 0, None, None),
    ("Onion",                     40,  1.1,  9.3, 4.2,  0.1, 0.04, 1.7,   4,  15, 1, None, 0,  110, "onion"),
    ("Bell pepper, red",          31,  1.0,  6.0, 4.2,  0.3, 0.06, 2.1,   4, None, 1, None, 0,  119, "pepper"),
    ("Cabbage",                   25,  1.3,  5.8, 3.2,  0.1, 0.03, 2.5,  18, None, 1, None, 0, None, None),
    ("Cauliflower",               25,  1.9,  5.0, 1.9,  0.3, 0.13, 2.0,  30, None, 1, None, 0, None, None),
    ("Courgette",                 17,  1.2,  3.1, 2.5,  0.3, 0.08, 1.0,   8, None, 1, None, 0, None, None),
    ("Aubergine",                 25,  1.0,  5.9, 3.5,  0.2, 0.03, 3.0,   2, None, 1, None, 0, None, None),
    ("Mushrooms, white",          22,  3.1,  3.3, 2.0,  0.3, 0.05, 1.0,   5, None, 1, None, 0, None, None),
    ("Lettuce",                   15,  1.4,  2.9, 0.8,  0.2, 0.03, 1.3,  28, None, 1, None, 0, None, None),
    ("Green beans",               31,  1.8,  7.0, 3.3,  0.2, 0.03, 2.7,   6, None, 1, None, 0, None, None),
    ("Beetroot, cooked",          44,  1.7, 10.0, 8.0,  0.2, 0.03, 2.0,  77,  64, 1, None, 0, None, None),
    ("Sweetcorn",                 86,  3.3, 19.0, 3.2,  1.4, 0.2,  2.0,  15,  52, 1, None, 0, None, None),
    ("Avocado",                  160,  2.0,  8.5, 0.7, 14.7, 2.1,  6.7,   7, None, 1, None, 0,  150, "avocado"),
    ("Garlic",                   149,  6.4, 33.1, 1.0,  0.5, 0.09, 2.1,  17, None, 1, None, 0,    3, "clove"),

    # ---- fruit ----
    ("Apple",                     52,  0.3, 13.8, 10.4, 0.2, 0.03, 2.4,   1,  36, 1, None, 0,  180, "apple"),
    ("Banana",                    89,  1.1, 22.8, 12.2, 0.3, 0.1,  2.6,   1,  51, 1, None, 0,  118, "banana"),
    ("Orange",                    47,  0.9, 11.8, 9.4,  0.1, 0.02, 2.4,   0,  43, 1, None, 0,  130, "orange"),
    ("Strawberries",              32,  0.7,  7.7, 4.9,  0.3, 0.02, 2.0,   1,  41, 1, None, 0, None, None),
    ("Blueberries",               57,  0.7, 14.5, 10.0, 0.3, 0.03, 2.4,   1,  53, 1, None, 0, None, None),
    ("Grapes",                    69,  0.7, 18.1, 15.5, 0.2, 0.05, 0.9,   2,  59, 1, None, 0, None, None),
    ("Pear",                      57,  0.4, 15.2, 9.8,  0.1, 0.02, 3.1,   1,  38, 1, None, 0,  178, "pear"),
    ("Watermelon",                30,  0.6,  7.6, 6.2,  0.2, 0.02, 0.4,   1,  76, 1, None, 0, None, None),
    ("Mango",                     60,  0.8, 15.0, 13.7, 0.4, 0.09, 1.6,   1,  51, 1, None, 0, None, None),
    ("Pineapple",                 50,  0.5, 13.1, 9.9,  0.1, 0.01, 1.4,   1,  59, 1, None, 0, None, None),
    ("Kiwi",                      61,  1.1, 14.7, 9.0,  0.5, 0.03, 3.0,   3,  50, 1, None, 0,   75, "kiwi"),
    ("Peach",                     39,  0.9,  9.5, 8.4,  0.3, 0.02, 1.5,   0,  42, 1, None, 0,  150, "peach"),
    ("Dates, dried",             282,  2.5, 75.0, 63.0, 0.4, 0.03, 8.0,   2,  42, 1, None, 0,    7, "date"),
    ("Raisins",                  299,  3.1, 79.0, 59.0, 0.5, 0.06, 3.7,  11,  64, 1, None, 0, None, None),
    ("Lemon",                     29,  1.1,  9.3, 2.5,  0.3, 0.04, 2.8,   2, None, 1, None, 0,   58, "lemon"),

    # ---- meat & poultry ----
    ("Chicken breast, raw",      120, 22.5,  0.0, 0.0,  2.6, 0.7,  0.0,  65, None, 1, None, 0, None, None),
    ("Chicken breast, cooked",   165, 31.0,  0.0, 0.0,  3.6, 1.0,  0.0,  74, None, 1, None, 0, None, None),
    ("Chicken thigh, cooked",    209, 26.0,  0.0, 0.0, 10.9, 3.0,  0.0,  88, None, 1, None, 0, None, None),
    ("Beef mince, 5% fat, raw",  137, 21.4,  0.0, 0.0,  5.0, 2.2,  0.0,  66, None, 1, None, 0, None, None),
    ("Beef mince, 20% fat, raw", 254, 17.2,  0.0, 0.0, 20.0, 7.7,  0.0,  67, None, 1, None, 0, None, None),
    ("Beef steak, sirloin",      212, 30.0,  0.0, 0.0,  9.6, 3.7,  0.0,  56, None, 1, None, 0, None, None),
    ("Pork loin, cooked",        242, 27.3,  0.0, 0.0, 14.0, 5.2,  0.0,  62, None, 1, None, 0, None, None),
    ("Lamb, cooked",             258, 25.0,  0.0, 0.0, 17.0, 7.5,  0.0,  72, None, 1, None, 0, None, None),
    ("Turkey breast, cooked",    135, 30.0,  0.0, 0.0,  0.7, 0.2,  0.0, 1015, None, 3, None, 0, None, None),
    ("Bacon, fried",             541, 37.0,  1.4, 0.0, 42.0, 14.0, 0.0, 2193, None, 4, None, 0,   12, "rasher"),
    ("Pork sausage",             301, 12.3,  9.3, 1.3, 24.3, 8.9,  1.0,  900, None, 4,  1.0, 0,   60, "sausage"),
    ("Ham, sliced",              145, 18.9,  3.4, 2.5,  5.5, 1.8,  0.6, 1200, None, 4,  2.0, 0,   28, "slice"),
    ("Salami",                   407, 22.0,  2.4, 0.8, 34.0, 12.0, 0.0, 2090, None, 4, None, 0, None, None),

    # ---- fish & seafood ----
    ("Salmon, raw",              208, 20.4,  0.0, 0.0, 13.4, 3.1,  0.0,  59, None, 1, None, 0, None, None),
    ("Salmon, cooked",           206, 22.0,  0.0, 0.0, 12.0, 2.5,  0.0,  61, None, 1, None, 0, None, None),
    ("Tuna, canned in water",    116, 25.5,  0.0, 0.0,  0.8, 0.2,  0.0, 247, None, 3, None, 0, None, None),
    ("Cod, cooked",              105, 22.8,  0.0, 0.0,  0.9, 0.2,  0.0,  78, None, 1, None, 0, None, None),
    ("Mackerel",                 205, 18.6,  0.0, 0.0, 13.9, 3.3,  0.0,  90, None, 1, None, 0, None, None),
    ("Sardines, canned",         208, 24.6,  0.0, 0.0, 11.5, 1.5,  0.0, 505, None, 3, None, 0, None, None),
    ("Prawns, cooked",            99, 24.0,  0.2, 0.0,  0.3, 0.1,  0.0, 111, None, 1, None, 0, None, None),

    # ---- dairy & eggs ----
    ("Egg, whole",               143, 12.6,  0.7, 0.4,  9.5, 3.1,  0.0, 142, None, 1, None, 0,   50, "egg"),
    ("Egg white",                 52, 10.9,  0.7, 0.7,  0.2, 0.0,  0.0, 166, None, 1, None, 0,   33, "white"),
    ("Milk, whole",               61,  3.2,  4.8, 5.1,  3.3, 1.9,  0.0,  43,  39, 1, None, 0, None, None),
    ("Milk, skimmed",             34,  3.4,  5.0, 5.0,  0.1, 0.06, 0.0,  42,  32, 1, None, 0, None, None),
    ("Greek yogurt, 0% fat",      59, 10.2,  3.6, 3.2,  0.4, 0.1,  0.0,  36,  11, 1, None, 0, None, None),
    ("Greek yogurt, full fat",    97,  9.0,  3.9, 4.0,  5.0, 3.2,  0.0,  35,  11, 1, None, 0, None, None),
    ("Yogurt, plain",             61,  3.5,  4.7, 4.7,  3.3, 2.1,  0.0,  46,  35, 1, None, 0, None, None),
    ("Cheddar cheese",           403, 24.9,  1.3, 0.5, 33.1, 21.0, 0.0, 621, None, 3, None, 0, None, None),
    ("Mozzarella",               280, 22.2,  2.2, 1.0, 17.1, 10.9, 0.0, 627, None, 3, None, 0, None, None),
    ("Cottage cheese",            98, 11.1,  3.4, 2.7,  4.3, 1.7,  0.0, 364, None, 3, None, 0, None, None),
    ("Feta",                     264, 14.2,  4.1, 4.1, 21.3, 14.9, 0.0, 1116, None, 3, None, 0, None, None),
    ("Parmesan",                 431, 38.5,  4.1, 0.8, 29.0, 19.0, 0.0, 1600, None, 3, None, 0, None, None),
    ("Butter",                   717,  0.9,  0.1, 0.1, 81.1, 51.4, 0.0,  11, None, 3, None, 0, None, None),
    ("Double cream",             340,  2.8,  2.8, 2.9, 36.0, 23.0, 0.0,  27, None, 3, None, 0, None, None),

    # ---- nuts & seeds ----
    ("Almonds",                  579, 21.2, 21.6, 4.4, 49.9, 3.8, 12.5,   1,  15, 1, None, 0, None, None),
    ("Walnuts",                  654, 15.2, 13.7, 2.6, 65.2, 6.1,  6.7,   2, None, 1, None, 0, None, None),
    ("Peanuts",                  567, 25.8, 16.1, 4.7, 49.2, 6.3,  8.5,  18,  14, 1, None, 0, None, None),
    ("Peanut butter",            588, 25.0, 20.0, 9.2, 50.0, 10.0, 6.0, 429,  14, 3,  6.0, 0, None, None),
    ("Cashews",                  553, 18.2, 30.2, 5.9, 43.9, 7.8,  3.3,  12,  25, 1, None, 0, None, None),
    ("Chia seeds",               486, 16.5, 42.1, 0.0, 30.7, 3.3, 34.4,  16, None, 1, None, 0, None, None),
    ("Sunflower seeds",          584, 20.8, 20.0, 2.6, 51.5, 4.5,  8.6,   9, None, 1, None, 0, None, None),
    ("Pumpkin seeds",            559, 30.2, 10.7, 1.4, 49.1, 8.7,  6.0,   7, None, 1, None, 0, None, None),
    ("Pistachios",               560, 20.2, 27.2, 7.7, 45.3, 5.9, 10.6,   1,  15, 1, None, 0, None, None),

    # ---- fats & oils ----
    ("Olive oil",                884,  0.0,  0.0, 0.0, 100.0, 13.8, 0.0,   2, None, 2, None, 0, None, None),
    ("Sunflower oil",            884,  0.0,  0.0, 0.0, 100.0, 10.3, 0.0,   0, None, 2, None, 0, None, None),
    ("Coconut oil",              862,  0.0,  0.0, 0.0, 100.0, 82.5, 0.0,   0, None, 2, None, 0, None, None),
    ("Mayonnaise",               680,  1.0,  0.6, 0.6,  75.0, 11.0, 0.0, 635, None, 4, None, 0, None, None),

    # ---- drinks ----
    ("Water",                      0,  0.0,  0.0, 0.0,  0.0, 0.0,  0.0,   0, None, 1, None, 0, None, None),
    ("Coffee, black",              2,  0.3,  0.0, 0.0,  0.0, 0.0,  0.0,   5, None, 1, None, 0, None, None),
    ("Tea, black, no milk",        1,  0.0,  0.3, 0.0,  0.0, 0.0,  0.0,   3, None, 1, None, 0, None, None),
    ("Orange juice",              45,  0.7, 10.4, 8.4,  0.2, 0.02, 0.2,   1,  50, 3, None, 0, None, None),
    ("Cola",                      42,  0.0, 10.6, 10.6, 0.0, 0.0,  0.0,   4,  63, 4, 10.6, 0, None, None),
    ("Energy drink",              45,  0.0, 11.0, 11.0, 0.0, 0.0,  0.0, 105,  68, 4, 11.0, 0, None, None),
    ("Beer, 5%",                  43,  0.5,  3.6, 0.0,  0.0, 0.0,  0.0,   4, None, 3, None, 3.9, None, None),
    ("Red wine",                  85,  0.1,  2.6, 0.6,  0.0, 0.0,  0.0,   4, None, 3, None, 10.6, None, None),
    ("Vodka, 40%",               231,  0.0,  0.0, 0.0,  0.0, 0.0,  0.0,   1, None, 3, None, 31.5, None, None),

    # ---- sweets & snacks ----
    ("Milk chocolate",           535,  7.6, 59.4, 51.5, 29.7, 18.5, 3.4,  79,  43, 4, 51.5, 0, None, None),
    ("Dark chocolate, 70%",      598,  7.8, 45.9, 24.0, 42.6, 24.5, 10.9, 20,  23, 4, 24.0, 0, None, None),
    ("Potato crisps",            536,  7.0, 53.0, 0.3,  34.6, 3.6,  4.8, 525,  54, 4, None, 0, None, None),
    ("Digestive biscuits",       480,  6.8, 62.5, 16.6, 21.4, 10.0, 3.5, 600,  60, 4, 16.6, 0,   15, "biscuit"),
    ("Ice cream, vanilla",       207,  3.5, 23.6, 21.2, 11.0, 6.8,  0.7,  80,  51, 4, 21.2, 0, None, None),
    ("Sugar, white",             387,  0.0, 100.0, 100.0, 0.0, 0.0, 0.0,   1,  65, 2, 100.0, 0,  4, "tsp"),
    ("Honey",                    304,  0.3, 82.4, 82.1, 0.0, 0.0,  0.2,   4,  61, 1, None, 0,   21, "tbsp"),
    ("Croissant",                406,  8.2, 45.8, 11.2, 21.0, 11.7, 2.6, 458, None, 4, 8.0, 0,   57, "croissant"),
    ("Doughnut",                 452,  4.9, 51.0, 22.0, 25.0, 11.0, 1.5, 326,  76, 4, 22.0, 0,  60, "doughnut"),

    # ---- prepared & fast food ----
    ("Pizza, margherita",        266, 11.0, 33.0, 3.6, 10.0, 4.5,  2.3, 598,  60, 4,  1.0, 0, None, None),
    ("Burger, fast food",        295, 17.0, 24.0, 5.0, 14.0, 5.5,  1.5, 497,  61, 4,  3.0, 0, None, None),
    ("Chips, fried",             312,  3.4, 41.0, 0.3, 15.0, 2.3,  3.8, 210,  63, 4, None, 0, None, None),
    ("Sushi, salmon roll",       142,  6.0, 24.0, 3.0,  2.5, 0.5,  1.0, 380,  55, 3,  2.0, 0, None, None),
    ("Instant noodles",          448,  9.4, 60.0, 1.5, 18.0, 8.5,  3.3, 1200, 47, 4, None, 0, None, None),

    # ---- supplements ----
    ("Whey protein powder",      400, 80.0,  8.0, 5.0,  6.0, 3.0,  1.0, 300, None, 4,  2.0, 0,   30, "scoop"),
    ("Protein bar",              380, 30.0, 35.0, 8.0, 12.0, 5.0,  6.0, 300, None, 4,  5.0, 0,   60, "bar"),
]

KEYS = ["name", "kcal", "protein", "carbs", "sugar", "fat", "satFat", "fibre",
        "sodiumMg", "gi", "nova", "addedSugar", "alcohol", "gramsPerPiece",
        "pieceName"]

foods = []
seen = set()
for row in F:
    assert len(row) == len(KEYS), f"{row[0]}: {len(row)} cols, expected {len(KEYS)}"
    item = {k: v for k, v in zip(KEYS, row) if v is not None}
    name = item["name"]
    assert name not in seen, f"duplicate: {name}"
    seen.add(name)

    # Sanity: macros must not imply wildly more energy than stated.
    implied = item["protein"] * 4 + item["carbs"] * 4 + item["fat"] * 9 \
        + item.get("alcohol", 0) * 7
    stated = item["kcal"]
    if stated > 20 and abs(implied - stated) > max(35, stated * 0.28):
        raise SystemExit(
            f"{name}: macros imply {implied:.0f} kcal but table says {stated}")

    # Sugar cannot exceed total carbohydrate; added sugar cannot exceed sugar.
    assert item["sugar"] <= item["carbs"] + 0.5, f"{name}: sugar > carbs"
    if "addedSugar" in item:
        assert item["addedSugar"] <= item["sugar"] + 0.5, f"{name}: added > total sugar"
    assert item["satFat"] <= item["fat"] + 0.1, f"{name}: satFat > fat"
    if "nova" in item:
        assert 1 <= item["nova"] <= 4, f"{name}: bad NOVA"
    if "gi" in item:
        assert 0 < item["gi"] <= 110, f"{name}: bad GI"
        assert item["carbs"] >= 2, f"{name}: GI on a food with no carbs"

    foods.append(item)

out = {
    "version": 1,
    "note": "Per 100 g (or 100 ml). Generic whole foods only - branded items "
            "come from Open Food Facts at runtime. gi is omitted where the "
            "food has too little carbohydrate for the measure to mean "
            "anything, which is not the same as a GI of zero.",
    "foods": foods,
}

dest = os.path.join(os.path.dirname(__file__), "seed_foods.json")
with open(dest, "w", encoding="utf-8", newline="\n") as fh:
    json.dump(out, fh, indent=1, ensure_ascii=False)
    fh.write("\n")

print(f"wrote {len(foods)} foods to {dest}")
