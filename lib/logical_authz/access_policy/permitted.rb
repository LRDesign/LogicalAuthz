module LogicalAuthz
  module AccessPolicy
    class Permitted < Rule
      register :permitted

      def initialize(specific_criteria = {})
        @criteria = specific_criteria
        super()
      end

      def predicate_text
        "permitted"
      end

      def matches_controller(table, controller_path)
        table["controller"].eq(controller_path)
      end

      def applies_to_resource(query, permissions_table, controller_path, action_aliases, subject_id)
        query.where(resource_application_clause(permissions_table, controller_path, action_aliases, subject_id))
      end

      def resource_application_clause(table, controller_path, action_aliases, subject_id)
        matches_controller(table, controller_path).and(
          matches_action(
            table["action"].eq(nil).and(table["subject_id"].eq(nil)),
            table, action_aliases, subject_id))
      end

      def matches_action(clause, table, action_aliases, subject_id)
        if action_aliases.empty? 
          return clause
        else
          return clause.or(
            if action_aliases.length == 1
              table["action"].eq(action_aliases.first.to_s)
            else
              table["action"].in(action_aliases.map{|a| a.to_s})
            end
          ).and(matches_subject(
            table["subject_id"].eq(nil), 
            table, subject_id))
        end
      end

      def matches_subject(clause, table, subject_id)
        if subject_id.nil?
          clause
        else
          clause.or(table["subject_id"].eq(subject_id))
        end
      end

      def name_and_range(permissions, roles)
        permissions["role_name"].eq(roles["role_name"]).and(
          permissions["role_range_id"].eq(roles["role_range_id"]))
      end

      def applies_to_consumer(query, roles_table, user, roles)
        unless user.nil?
          query.where(roles_table["authnd_id"].eq(user.id))
        else
          query.where(roles_table["id"].in(roles))
        end
      end

      def check(criteria)
        crits = criteria.merge(@criteria)

        permissions = Permission.arel_table
        roles = Role.arel_table

        query = permissions.join(roles).on(name_and_range(permissions, roles))

        applies_to_consumer(query, roles,
                            criteria[:user], 
                            criteria[:roles])
        applies_to_resource(query, permissions,
                            criteria[:controller_path], 
                            criteria[:action_aliases], 
                            criteria[:id])

        if Permission.count_by_sql(query.project(Arel.sql('*').count).to_sql) > 0
          laz_debug{ "Permitted" }
          return true
        else
          laz_debug{ "Not permitted: 0 rows returned"}
          laz_debug do
            debug_q = applies_to_consumer(permissions.join(roles).on(name_and_range(permissions, roles)), roles, *criteria.values_at(:user, :roles)).project(Arel::sql('*'))
            "Related permissions:" + Permission.find_by_sql(debug_q.to_sql).map{|perm| "\n   " + perm.inspect}.join("")
          end
          laz_debug{ "Resource to match: #{criteria.values_at(:controller_path, :action_aliases, :id).inspect}" }
          return false
        end
      end
    end
  end
end


