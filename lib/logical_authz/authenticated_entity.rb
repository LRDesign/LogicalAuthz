module LogicalAuthz
  module AuthenticatedEntity
    def self.included(base)
      base.has_many :roles, :foreign_key => "authnd_id"
    end
  end

  User = AuthenticatedEntity #Because there's correct and there's jerky
end
