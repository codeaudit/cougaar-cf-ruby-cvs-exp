#!/usr/local/bin/ruby

require 'date'
require 'parsedate'
require 'cgi'

class DateLine
	TIMEZONE_OFFSET = 18000
	attr_reader :date, :author
	def initialize(rawText)
		a = rawText.index("(date: ")+7
		b = rawText.index("  ", a)
		dateStr = rawText[a, 10].gsub("/","-")
		dateArr = ParseDate::parsedate(dateStr)
		a = rawText.index(" ", a)
		b = rawText.index(";", a)
		timeStr = rawText[a+1, b-a-1]
		timeArr = timeStr.split(":")
		@date = Time.gm(dateArr[0], dateArr[1], dateArr[2],timeArr[0],timeArr[1],timeArr[2]) - TIMEZONE_OFFSET
		a = rawText.index("author") + 8 
		b = rawText.index(";", a)
		authorLine=`grep "#{rawText[a, b-a]}:" /etc/passwd`
		@author = authorLine.split(":")[4]
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
 def add(rawText)
  a = rawText.index("| ") + 2
  b = rawText.index(":", a)
 	filename=rawText[a, rawText.length-2]
  # when is the filename ever null?
	@list.push(filename) unless filename == nil
 end
end

class Entry
	attr_reader :dateLine, :files, :comment
	def initialize(dateLine,files, comment)
		@dateLine = dateLine
		@files = files
		@comment=comment
	end
	def get_date_with_nice_format
		@dateLine.date.strftime("%m/%d/%Y %I:%M %p")
	end
end

class Params
	attr_reader :root, :moduleDir, :branch, :cvsexpLocation, :max_age
	def initialize(cvsexpLocation, root, moduleDir, branch, max_age)
		@cvsexpLocation = cvsexpLocation
		@root = root
		@branch = branch
		@moduleDir = moduleDir
		@max_age = max_age
	end
	def to_s
		s = "cvsexpLocation = " + @cvsexpLocation + "\n"
		s << "root = " + @root + "\n"
		s << "branch = " + @branch + "\n"
		s << "moduleDir = " + @moduleDir + "\n"
		s << "max_age = " + @max_age.to_s + "\n"
	end
end

class CVSLogWrapper
	attr_reader :entries, :rawText
	def initialize(params)
		ENV['CVSROOT']=params.root
		@branch = params.branch
		branchStr = @branch == "HEAD" ? "" : "-r" + @branch
		@entries = []
		cmd = "perl #{params.cvsexpLocation} --notree #{branchStr} 2>/dev/null"
		rawText = `#{cmd}`
		blocks = rawText.split("==============================================================================")
		blocks.each do |block|
			lines=block.split("\n")
			# check to see if this is our target branch
			if lines[1] == "BRANCH [#{params.branch}]"
				addEntry(lines, 3, params.moduleDir, params.max_age)
			elsif lines[1] == ""
				# not our target branch, and first line is blank, so it's the HEAD
				addEntry(lines, 2, params.moduleDir, params.max_age)
			end
		end
		@entries.sort {|a,b| return a.dateLine.date <=> b.dateLine.date}
	end 

	def addEntry(lines, dateLineIndex, targetModuleDir, max_age)
		dateline=DateLine.new(lines[dateLineIndex])
		return unless !dateline.older_than(max_age)
		files=Files.new
		lines.each do |line|
			files.add(line) unless line[" | "] == nil
		end
		comment = nil
		lines.each_index do |idx|
			if lines[idx]["`----------------------------------------"] != nil
				comment = lines[idx+2]	
				break
			end
		end
		@entries << Entry.new(dateline,files,comment) unless files.list[0][targetModuleDir] == nil
	end 

	def dump
		@entries.each do |e|
			e.files.list.each do |f|
				puts e.get_date_with_nice_format + ":" + e.dateLine.author + ":" + f + ":" + e.comment
			end
		end
	end

	def getHTML
		page = "<div align=\"center\"><table style=\"font-size:90%\"><tr><th>When</th><th>Who</th><th>What</th><th>Why</th></tr>"
		@entries.reverse.each do |e|
			e.files.list.each do |file|
				page << "<tr bgcolor=\"#CCFFCC\"><td nowrap>" + 
								e.get_date_with_nice_format + "</td> <td nowrap>" + 
								e.dateLine.author + "</td> <td> " + 
								file + "</td><td>" + 
								e.comment.to_s + "</td></tr>"
			end
		end
		page << "</table></div></body></html>"
		return page
	end
end

if __FILE__ ==$0 
	root, moduleDir, branch, max_age = ARGV[0], ARGV[1], ARGV[2], ARGV[3].to_i
	p = Params.new("/tmp/histwork/cvs-exp.pl", root, moduleDir, branch, max_age)
	c = CVSLogWrapper.new(p)
	c.dump
end
