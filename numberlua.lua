if bitop then
    -- Add support for CCTweaks' bitop functions
    -- These are significantly faster than vanilla CC's
    local bit = bitop
    bxor = bitop.bxor
    bnot = bitop.bnot
    band = bitop.band
    bor = bitop.bor
    rshift = bitop.rshift
    lshift = bitop.lshift
    arshift = bitop.arshift
else
    local bit = bit
    bxor = bit.bxor
    bnot = bit.bnot
    band = bit.band
    bor = bit.bor
    rshift = bit.blogic_rshift
    lshift = bit.blshift
    arshift = bit.brshift
end