print("Testing vim.pack...")
if vim.pack then
    print("vim.pack exists")
    for k, v in pairs(vim.pack) do
        print("  " .. k .. " (" .. type(v) .. ")")
    end
else
    print("vim.pack does NOT exist")
end

if _G.WimPackAdd then
    print("WimPackAdd exists in global scope")
end
