local categories = {}

categories.list = {
    -- None
    [0]   = 'None',

    -- Weapons
    [1]   = 'Weapons->Hand-to-Hand',
    [2]   = 'Weapons->Daggers',
    [3]   = 'Weapons->Swords',
    [4]   = 'Weapons->Great Swords',
    [5]   = 'Weapons->Axes',
    [6]   = 'Weapons->Great Axes',
    [7]   = 'Weapons->Scythes',
    [8]   = 'Weapons->Polearms',
    [9]   = 'Weapons->Katana',
    [10]  = 'Weapons->Great Katana',
    [11]  = 'Weapons->Clubs',
    [12]  = 'Weapons->Staves',
    [13]  = 'Weapons->Ranged',
    [14]  = 'Weapons->Instruments',
    [15]  = 'Weapons->Ammo&Misc->Ammunition',
    [47]  = 'Weapons->Ammo&Misc->Fishing Gear',
    [48]  = 'Weapons->Ammo&Misc->Pet Items',
    [62]  = 'Weapons->Ammo&Misc->Grips',

    -- Armor
    [16]  = 'Armor->Shields',
    [17]  = 'Armor->Head',
    [22]  = 'Armor->Neck',
    [18]  = 'Armor->Body',
    [19]  = 'Armor->Hands',
    [23]  = 'Armor->Waist',
    [20]  = 'Armor->Legs',
    [21]  = 'Armor->Feet',
    [26]  = 'Armor->Back',
    [24]  = 'Armor->Earrings',
    [25]  = 'Armor->Rings',

    -- Scrolls
    [28]  = 'Scrolls->White Magic',
    [29]  = 'Scrolls->Black Magic',
    [32]  = 'Scrolls->Songs',
    [31]  = 'Scrolls->Ninjutsu',
    [30]  = 'Scrolls->Summoning',
    [60]  = 'Scrolls->Dice',
    [45]  = 'Scrolls->Geomancy',

    -- Medicines
    [33]  = 'Medicines',

    -- Furnishings
    [34]  = 'Furnishings',

    -- Materials
    [38]  = 'Materials->Smithing',
    [39]  = 'Materials->Goldsmithing',
    [40]  = 'Materials->Clothcraft',
    [41]  = 'Materials->Leathercraft',
    [42]  = 'Materials->Bonecraft',
    [43]  = 'Materials->Woodworking',
    [44]  = 'Materials->Alchemy',
    [63]  = 'Materials->Alchemy 2',

    -- Food
    [52]  = 'Food->Meals->Meat&Eggs',
    [53]  = 'Food->Meals->Seafood',
    [54]  = 'Food->Meals->Vegetables',
    [55]  = 'Food->Meals->Soups',
    [56]  = 'Food->Meals->Breads&Rice',
    [57]  = 'Food->Meals->Sweets',
    [58]  = 'Food->Meals->Drinks',
    [59]  = 'Food->Ingredients',
    [51]  = 'Food->Fish',

    -- Crystals
    [35]  = 'Crystals',

    -- Others
    [46]  = 'Others->Misc.',
    [64]  = 'Others->Misc.2',
    [65]  = 'Others->Misc.3',
    [50]  = 'Others->Beast-Made',
    [36]  = 'Others->Cards',
    [49]  = 'Others->Ninja Tools',
    [37]  = 'Others->Cursed Items',
    [61]  = 'Others->Automatons',

    -- Unused
    [27]  = 'Unused',

    -- All
    [999] = 'All'
}

categories.order = {
    999, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 15, 47, 48, 62, 16,
    17, 22, 18, 19, 23, 20, 21, 26, 24, 25,
    28, 29, 32, 31, 30, 60, 45, 33, 34, 38,
    39, 40, 41, 42, 43, 44, 63, 52, 53, 54,
    55, 56, 57, 58, 59, 51, 35, 46, 64, 65,
    50, 36, 49, 37, 61,
}

return categories
