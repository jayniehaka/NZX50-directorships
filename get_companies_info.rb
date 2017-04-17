#! /usr/bin/env ruby

# reads a csv file of company tickers and numbers
# scrapes NZ companies office site to get company and director details
# creates nodes table and edges table csv files to import into Gephi

# set working directory to the same dir in which this script is saved
Dir.chdir(File.dirname(__FILE__))
# my file with names & numbers of NZX50 companies
data_file_name = "NZX50.csv"

# yay, gems!
require 'csv'
require 'nokogiri'
require 'open-uri'

# create a class called node
class Node
  attr_reader :short_name, :full_name, :entity
  attr_writer :short_name, :full_name, :entity
   def initialize(short_name, full_name, entity)
      @short_name=short_name
      @full_name=full_name
      @entity=entity
   end
end

# create a class called edge
class Edge
  attr_reader :source, :target, :value
  attr_writer :source, :target, :value
   def initialize(source, target, value)
      @source=source # director
      @target=target # company
      @value=value
   end
end

# create arrays for nodes (names and directors) and edges tables
nodes = Array.new
edges = Array.new

# create a hash of company tickers and company numbers from the csv file
company_ids = Hash.new
CSV.foreach(data_file_name) do |row|
   ticker = row[0]
   number = row[1]
   company_ids[ticker.to_s] = number.to_s
end

# iterate over company numbers
company_count = company_ids.count
company_status = 0

company_ids.each do |company_ticker, company_number|
 # set companies office URLs to scrape
 company_url = "https://www.business.govt.nz/companies/app/ui/pages/companies/" + company_number
 nzco_page = Nokogiri::HTML(open(company_url))

 # scrape company name and tidy up
 full_company_name = nzco_page.xpath('//h1')[0].text
 company_name_match = full_company_name.match(/.+(?=\(\d+\)\s+Registered)/)  Matches string preceding numbers enclosed in brackets and "Registered" at end of line
 company_name = company_name_match[0]                                         # Gets first match
 company_name = company_name.strip                                            # Strips extra spaces

 # create new node object
 new_company = Node.new(company_ticker, company_name, 1)
 company_status = company_status + 1

 # add object to companies array
 nodes << new_company
 target_id = nodes.count - 1

 # get directors
 directors_url = company_url + '/directors'
 nzco_dirs_page = Nokogiri::HTML(open(directors_url))

 # iterate over the company's directors
 company_directors = nzco_dirs_page.xpath('//td[@class = "director"]/div[@class = "row"]/label[@for = "fullName"]/following-sibling::node()')
 company_directors = company_directors.to_a # change from class Nokogiri::XML::NodeSet to array
 
 company_directors.each do |director_name|

    # get rid of stupid line breaks in name
    director_name = director_name.to_s
    director_name = director_name.gsub("\r", " ")
    director_name = director_name.gsub("\n", " ")
    director_name = director_name.gsub(/\s+/, ' ')
    director_name = director_name.strip

    # split out last name
    director_lastname_match = director_name.match(/[A-Z]{2,}.*[[A-Z]{2,}]*/)  # Matches part of the name in caps
    director_lastname = director_lastname_match[0]                            # Gets first match

   source_id = 999999
   # Check in the nodes array in case there is already an object which has the same full name
   if nodes.any? {|director| director.full_name == director_name}
      # Find the matching director and get the id to push to the edges array
     nodes.each_with_index do |node, i|
       if node.full_name == director_name
          source_id = i
       end
     end
   else
      new_director = Node.new(director_lastname, director_name, 2)  # create new node object
      nodes << new_director                                      # push to nodes array
      source_id = nodes.count - 1                                # use index in nodes array as source_id
   end
  
   # Checks if directorship is already in edges array
   if not edges.any? {|edge| edge.source == source_id && edge.target == target_id}
      new_directorship = Edge.new(source_id, target_id, 1)  # create edge for the directorship 
      edges << new_directorship                             # push to edge array
   end   
 end # end of director loop

 # give a status update
 puts "Scraped company " + company_status.to_s + " of " + company_count.to_s
end # end of company loop

# make csv files
nodes_heading = "name;fullname;group\n"
edges_heading = "source;target;talue\n"

new_file = File.basename(data_file_name, ".*")

# Creates a new file and write nodes table
File.open("nodes_table_" + new_file + ".csv", "w") do |nodes_file|  
	
	nodes_file.puts nodes_heading

	# Writes nodes table
	nodes.each do |node|
  		nodes_file.puts "\"" + node.short_name + "\";\"" + node.full_name + "\";\"" + node.entity.to_s + "\"\n"
	end
end

# Creates a new file and writes edges table
File.open("edges_table_" + new_file + ".csv", "w") do |edges_file|  

	edges_file.puts edges_heading

	# Writes "director of" edges table
	edges.each do |edge|
		edges_file.puts edge.source.to_s + ";" + edge.target.to_s + ";" + edge.value.to_s + "\n"
	end
end

puts "All finished!"

