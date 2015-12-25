Pod::Spec.new do |s|
  s.name         = "ZCTableviewHeightCache"  
  s.version      = "0.0.1"  
  s.summary      = "UITableViewCell height cache" 
  s.homepage     = "https://github.com/ooppstef/UITableView-ZCTableCellHeightCache"
  s.license      = "MIT" 
  s.platform     = :ios, "7.0"    
  s.source       = { :git => "https://github.com/ooppstef/UITableView-ZCTableCellHeightCache.git", :tag => s.version }
  s.source_files  = "UITableView-ZCTableCellHeightCache/*" 
  s.requires_arc = true
end