itemFlags = {
    None = 0x0000,
    Flag00 = 0x0001,
    Flag01 = 0x0002,
    Flag02 = 0x0004,
    Flag03 = 0x0008,
    Flag04 = 0x0010,
    Inscribable = 0x0020,
    NoAuction = 0x0040,
    Scroll = 0x0080,
    Linkshell = 0x0100,
    CanUse = 0x0200,
    CanTradeNPC = 0x0400,
    CanEquip = 0x0800,
    NoSale = 0x1000,
    NoDelivery = 0x2000,
    NoTradePC = 0x4000,
    Rare = 0x8000,
    Ex = 0x6040 -- NoAuction, NoDelivery, NoTrade
}

return itemFlags
