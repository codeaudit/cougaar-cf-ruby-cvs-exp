#!/usr/local/bin/ruby

require 'cgi'
require 'CVSHistory'

WORKING_DIR="/tmp/histwork/"
PATH_TO_CVS_EXP="/tmp/histwork/cvs-exp.pl"

cgi = CGI.new("html3")
root=cgi['root'][0]
moduleDir=cgi['moduleDir'][0]
branch=cgi['branch'][0]
days=30
if cgi['days'][0] != nil
	days = cgi['days'][0]
end

Dir.mkdir(WORKING_DIR) unless File.exists?(WORKING_DIR)

cgi.out {
	cgi.html {
		cgi.body {
			ENV['CVSROOT'] = root
			Dir.chdir(WORKING_DIR)
			`cvs -Q co #{moduleDir}`
			c = CVSLogWrapper.new(Params.new(PATH_TO_CVS_EXP, root, moduleDir, branch, days.to_i))
			`rm -rf #{moduleDir}`
			c.getHTML()
		}
	}
}

