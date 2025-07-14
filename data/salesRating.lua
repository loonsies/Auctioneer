local salesRating = {}

salesRating.labels = {
    'Dead Slow',
    'Very Slow',
    'Slow',
    'Average',
    'Fast',
    'Very Fast'
}

salesRating.thresholds = {
    { 8,      6 },
    { 4,      5 },
    { 1,      4 },
    { 1 / 7,  3 },
    { 1 / 30, 2 },
    { 0,      1 }
}

salesRating.colors = {
    '888888',
    'D20000',
    'FEAD3F',
    'BBBB00',
    '33CC33',
    '339900'
}

return salesRating
