#!/usr/local/bin/ruby

require 'cgi'
require 'CVSHistory'

ALLOWED_ROOT = "/cvs"

cgi = CGI.new("html3")
root=cgi.params['root'][0]

msg = "The CVSROOT #{root} is not allowed"
if root =~ /^#{ALLOWED_ROOT}/
	moduleDir=cgi.params['moduleDir'][0]
	branch=cgi.params['branch'][0]
	days = !cgi.params['days'][0].nil? ? cgi.params['days'][0] : 5
	p = Params.new(root.to_s, moduleDir.to_s, branch.to_s, days.to_i)
	Dir.chdir(WORKING_DIRECTORY)
	`cvs -Q -d#{root} co #{p.module_directory}`
	msg = CVSLogWrapper.new(p).getHTML
end

cgi.out {
		cgi.html {
			cgi.body {
				msg
			}
	}
}
