#!/usr/local/bin/ruby

require 'date'
require 'parsedate'
require 'cgi'

class CVSLogWrapper
 attr_reader :entries, :rawText
 def initialize(params)
  ENV['CVSROOT']=params.root
  @branch = params.branch
  branchStr=""
  if @branch != "HEAD"
   branchStr = "-r#{@branch}"
  end
  @entries = []
  @rawText = `perl #{params.cvsexpLocation} --notree #{branchStr} 2>/dev/null`
  blocks = @rawText.split("==============================================================================")
  blocks.each do |block|
   lines=block.split("\n")
   # check to see if this is our target branch
   if lines[1] == "BRANCH [#{params.branch}]"
    addEntry(lines, 3, params.moduleDir, params.maximumAge)
   elsif lines[1] == ""
    # not our target branch, and first line is blank, so it's the HEAD
    addEntry(lines, 2, params.moduleDir, params.maximumAge)
   end
  end
  sort
  @entries.reverse!
 end 

def addEntry(lines, dateLineIndex, targetModuleDir, maximumAge)
 dateLine=DateLine.new(lines[dateLineIndex])
 if dateLine.olderThan(maximumAge)
  return
 end
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
 entries << Entry.new(dateLine,files,comment) unless files.list[0][targetModuleDir] == nil
end 

 def sort
  @entries.sort {|a,b| return a.dateLine.date <=> b.dateLine.date}
 end

 def dump
   entries.each do |entry|
    entry.files.list.each do |file|
     dateStr = entry.dateLine.date.strftime("%m/%d/%Y %I:%M %p")
     puts "#{dateStr}:#{entry.dateLine.author}:#{file}:#{entry.comment}"
    end
   end
 end

 def getHTML()
  page = "<div align=\"center\"><table style=\"font-size:90%\"><tr><th>When</th><th>Who</th><th>What</th><th>Why</th></tr>"
  currentTime = Time.now
   entries.each do |entry|
    entry.files.list.each do |file|
     dateStr = entry.dateLine.date.strftime("%m/%d/%Y %I:%M %p")
     page << "<tr bgcolor=\"#CCFFCC\"><td nowrap>#{dateStr}</td> <td nowrap>#{entry.dateLine.author}</td> <td>#{file}</td><td>#{entry.comment}</td></tr>"
    end
   end
   page << "</table></div>"
   return page
 end
end

class DateLine
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
  @date = Time.gm(dateArr[0], dateArr[1], dateArr[2],timeArr[0],timeArr[1],timeArr[2])
  
	a = rawText.index("author") + 8 
  b = rawText.index(";", a)
  authorID = rawText[a, b-a]
  authorLine=`grep "#{authorID}:" /etc/passwd`
  @author = authorLine.split(":")[4]
 end
 def olderThan(days)
	return date + (days*86400) < Time.now
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
 def size 
  return @list.size
 end
end

class Entry
 attr_reader :dateLine, :files, :comment
 def initialize(dateLine,files, comment)
  @dateLine = dateLine
  @files = files
  @comment=comment
 end
end

class Params
 attr_reader :root, :moduleDir, :branch, :cvsexpLocation, :maximumAge
 def initialize(cvsexpLocation, root, moduleDir, branch, maximumAge)
  @cvsexpLocation = cvsexpLocation
  @root = root
  @branch = branch
  @moduleDir = moduleDir
  @maximumAge = maximumAge
 end
end

if __FILE__ ==$0 
 p = Params.new("/home/build/tmp/cvs-exp.pl", ARGV[0], ARGV[1], ARGV[2], ARGV[3].to_i)
 c = CVSLogWrapper.new(p)
 c.dump()
end
