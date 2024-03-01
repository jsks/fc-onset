PANDOC_VERSION:must_be_at_least '3.1.8'

function shell(cmd)
   local fd = io.popen(cmd)
   local output = fd:read("*a")
   local rc = {fd:close()}

   return rc[3], output:gsub("\n*$", "")
end

function github_base()
   local _, url = shell("git config --get remote.origin.url")
   return url:gsub("git@", ""):gsub(":", "/")
end

function Meta(meta)
   local git_status, commit = shell("git rev-parse --short HEAD")
   if git_status == 0 then
      local url = string.format("https://%s/tree/%s", github_base(), commit)
      meta.commit = pandoc.Link(commit, url)
   end

   _, meta.wordcount = shell("scripts/wordcount.sh " .. quarto.doc.input_file)

   return meta
end


return {
    { Meta = Meta }
}
