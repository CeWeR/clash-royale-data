require 'nokogiri'
require 'open-uri'
require 'vcr'
require 'digest/sha1'
require 'json'

VCR.configure do |c|
  c.cassette_library_dir = 'vcr_cassettes'
  c.hook_into :webmock
end

def base_url
  'http://www.clashroyaleguides.com/'
end

def get_replayable_document_from_url(*parts)
  url = parts.join('/')
  hash = Digest::SHA1.hexdigest url
  doc = nil

  VCR.use_cassette(hash) do
    doc = Nokogiri::HTML(open(url))
  end
  doc
end

def build_from_rows(rows)
  res, header  = [], []

  rows.each do |r|
    if header.empty?
      r.children.select {|e| e.node_name == 'th'}.each do |td|
        header << td.content.strip.downcase.gsub(/\s+/, '_')
      end
    else
      values = []
      r.children.select {|e| e.node_name == 'td'}.each do |td|
        values << td.content.strip
      end

      res << Hash[*header.zip(values).flatten]
    end
  end

  res
end

def load_from_web(type, name)
  doc = get_replayable_document_from_url base_url, type, name
  basis_html, level_info_html = doc.css('#main-content article table')

  object = build_from_rows(basis_html.css 'tr')[0]
  level_infos = build_from_rows(level_info_html.css 'tr') 

  object['levels'] = level_infos
  object
end

infos = {}
[ 'royal-giant', 'skeletons', 'bomber', 'archer', 'knight', 'three-musketeers',
  'baby-dragon', 'barbarians', 'dark-prince', 'minion-horde', 'princess', 
  'ice-wizard', 'golem', 'wizard', 'hog-rider', 'giant', 'giant-skeleton',
  'p-e-k-k-a', 'balloon', 'prince', 'minions', 'goblins', 'witch',
  'mini-p-e-k-k-a', 'musketeer', 'valkyrie', 'clash-royale-skeleton-army',
  'spear-goblin'
].each do |character_name|
  infos[character_name] = load_from_web 'characters', character_name
end

[ 'poison', 'mirror', 'zap', 'freeze', 'rage', 'rocket', 'goblin-barrel', 
  'fireball', 'lightning', 'arrows'
].each do |spell_name|
  loaded_info = load_from_web 'spell-cards', spell_name
  infos[spell_name] = loaded_info
end

[ 'mortar', 'elixir-collector', 'x-bow', 'cannon', 'barbarian-hut', 
  'inferno-tower','bomb-tower', 'goblin-hut', 'tesla', 'tombstone'
].each do |building_name|
  loaded_info = load_from_web 'building-cards', building_name
  infos[building_name] = loaded_info
end

# Output JSON Info
File.open('../data/info.json', 'w') do |f|
  f.write JSON.pretty_generate(infos)
end
