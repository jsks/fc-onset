PANDOC_VERSION:must_be_at_least '3.1.8'

function shell(cmd)
   local fd = io.popen(cmd)
   return fd:read('*a')
end

function Meta(meta)
   local commit = shell("git rev-parse --short HEAD"):gsub("\n*$", "")
   meta.commit = pandoc.Link(commit, "https://github.com/jsks/fc-onset/tree/" .. commit)
   meta.wordcount = shell("scripts/wordcount.sh " .. quarto.doc.input_file)

   return meta
end


return {
    { Meta = Meta }
}
