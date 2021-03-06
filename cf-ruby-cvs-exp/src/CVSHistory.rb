#!/usr/local/bin/ruby

require 'date'
require 'parsedate'
require 'cgi'

CVS_EXP="/tmp/histwork/cvs-exp.pl"
WORKING_DIRECTORY="/tmp/histwork"

class DateLine
	TIMEZONE_OFFSET = 18000
	attr_reader :date, :author
	def initialize(raw_text)
		dateArr = ParseDate::parsedate(raw_text[/\w[0-9]*\/[0-9]*\/[0-9]*/])
		timeArr = raw_text[/[0-9]*:[0-9]*:[0-9]*/].split(":")
		@date = Time.gm(dateArr[0], dateArr[1], dateArr[2],timeArr[0],timeArr[1],timeArr[2]) - TIMEZONE_OFFSET
		@author = `grep "#{raw_text[/author: [a-z0-9]*\b/].split(":")[1].strip}:" /etc/passwd`.split(":")[4]
	end
	def older_than(days)
		date + (days*86400) < Time.now
	end
end

class Files
 attr_reader :list
 def initialize 
  @list = []
 end
 def add(raw_text)
	@list << raw_text[/\|.*\:/][1, raw_text[/\|.*\:/].length-2].strip
 end
end

class Entry
	attr_reader :date_line, :files, :comment
	def initialize(date_line,files, comment)
		@date_line = date_line
		@files = files
		@comment=comment
	end
	def get_date_with_nice_format
		@date_line.date.strftime("%m/%d/%Y %I:%M %p")
	end
end

class Params
	attr_reader :root, :module_directory, :branch, :max_age
	def initialize(root, module_directory, branch, max_age)
		@root = root
		@branch = branch
		@module_directory = module_directory
		@max_age = max_age
	end
	def to_s
		s = "cvsexpLocation = " + CVS_EXP + "\n"
		s << "root = " + @root + "\n"
		s << "branch = " + @branch + "\n"
		s << "module_directory = " + @module_directory + "\n"
		s << "max_age = " + @max_age.to_s + "\n"
	end
end

class CVSLogWrapper
	attr_reader :entries, :raw_text
	def initialize(params)
		ENV['CVSROOT']=params.root
		@branch = params.branch
		@entries = []
		@skipped = []

		cmd = "perl #{CVS_EXP} --notree #{@branch == "HEAD" ? "" : "-r" + @branch} 2>/dev/null"
		raw_text = `#{cmd}`
		blocks = raw_text.split("==============================================================================")
		blocks.each do |block|
			lines=block.split("\n")
			# check to see if this is our target branch
			if lines[1] == "BRANCH [#{params.branch}]"
				d = DateLine.new(lines[3])
				add_entry(lines, params, d) unless d.older_than(params.max_age)
			elsif lines[1] == ""
				# not our target branch, and first line is blank, so it's the HEAD
				d = DateLine.new(lines[2])
				add_entry(lines, params, d) unless d.older_than(params.max_age)
			else
				# it's part of the initial import, so skip it
				@skipped << lines
			end
		end
		@entries.sort{|a,b| a.date_line.date <=> b.date_line.date}
	end 
	def add_entry(lines, params, dateline)
		files=Files.new
		lines.each { |line| files.add(line) unless line[" | "] == nil }
		comment = nil
		lines.each_index do |idx|
			if lines[idx] =~ /`----------------------------------------/
				comment = lines[idx+2]	
				break
			end
		end
		@entries << Entry.new(dateline,files,comment) unless files.list[0][params.module_directory] == nil
	end 
	def html(show_skipped_entries=false)
		page = "<div align=\"center\"><table style=\"font-size:90%\"><tr><th>When</th><th>Who</th><th>What</th><th>Why</th></tr>"
		@entries.reverse.each { |e|
			e.files.list.each { |file|
				page << "<tr bgcolor=\"#CCFFCC\"><td nowrap>" + 
								e.get_date_with_nice_format + "</td> <td nowrap>" + 
								e.date_line.author + "</td> <td> " + 
								file + "</td><td>" + 
								e.comment + "</td></tr>\n"
			}
		}
		@skipped.each {|e| page << "<tr><td>#{e}</td></tr>" } if show_skipped_entries
		page << "</table></div></body></html>"
	end
	def dump
		@entries.reverse.each { |e|
			e.files.list.each { |f|
				puts e.get_date_with_nice_format + ":" + e.date_line.author + ":" + f + ":" + e.comment
			}
		}
	end
end

if __FILE__ ==$0 
	if ARGV.length != 4
		puts "Usage: CVSHistory.rb /cvs/commons/isat/ ticenvironment HEAD 20"
		exit
	end
	root, module_directory, branch, max_age = ARGV[0], ARGV[1], ARGV[2], ARGV[3].to_i
	p = Params.new(root, module_directory, branch, max_age)
	Dir.chdir(WORKING_DIRECTORY)
  `cvs -Q -d#{root} co #{p.module_directory}`
	CVSLogWrapper.new(p).dump
end
