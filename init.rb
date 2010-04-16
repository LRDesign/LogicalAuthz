ActionView::Base.send :include, LogicalAuthz::Helper
p ActiveSupport::Dependencies::load_once_paths
