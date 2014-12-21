function getDefaultPlatform()
    return decodeFromFile(fs.combine(asmDir, "platform.json"))
end