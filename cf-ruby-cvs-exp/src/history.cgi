#!/usr/local/bin/ruby

require 'cgi'
require 'CVSHistory'

CVS_EXP="/tmp/histwork/cvs-exp.pl"
WORKING_DIRECTORY="/tmp/histwork"

cgi = CGI.new("html3")
root=cgi.params['root'][0]
moduleDir=cgi.params['moduleDir'][0]
branch=cgi.params['branch'][0]
days = 5
if cgi.params['days'][0] != nil
	days = cgi.params['days'][0]
end

cgi.out {
	cgi.html {
		cgi.body {
			p = Params.new(CVS_EXP, root.to_s, moduleDir.to_s, branch.to_s, days.to_i)
			Dir.chdir(WORKING_DIRECTORY)
			`cvs -Q -d#{root} co #{p.moduleDir}`
			CVSLogWrapper.new(p).getHTML
		}
	}
}

