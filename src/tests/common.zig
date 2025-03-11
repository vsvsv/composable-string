pub const valid_utf8_strings = [_][]const u8{
    "All your base are belong to us",
    "\xc3\xb1",
    "\xe2\x82\xa1",
    "\xf0\x90\x8c\xbc",
    zalgo_text,
};

pub const invalid_utf8_strings = [_][]const u8{
    "\xc3\x28",
    "\xa0\xa1",
    "\xe2\x28\xa1",
    "\xe2\x82\x28",
    "\xf0\x28\x8c\xbc",
    "\xf0\x90\x28\xbc",
    "\xf0\x28\x8c\x28",
    "\xf8\xa1\xa1\xa1\xa1",
    "\xfc\xa1\xa1\xa1\xa1\xa1",
};

pub const zalgo_text = "H̴̳̬̓̏o̵̖̬̽̒̓w̴̲̬͗͜ ̷̝̒͆ǟ̵̯͛͘b̴̡̩̥̱̈͠͠o̷̤͔̐͛ū̴̩̇̂̍ẗ̷͙̝́̉͝ ̵̜̲̣̈́̆̍s̵͓͝o̷̡̦̝̳͌ṁ̴̰͈̩̈́̌͘ẻ̶̟͗̉̀ ̶̛̜̀͑Z̸̤̲̄̓͆̓ȧ̶͈̩̎͗l̷̲̾͗g̸̦͊ỏ̶̞͓ͅ ̶̤̠̆̋̈́̃ẗ̴͔̖̪̅͊̚e̷̗̟̻̫̔̚x̴͖̫͈̼̉ţ̶̜̤̽̀̊́?̷̢̛̇̂̚"; // character count: 23, byte count: 334
