module ActiveRecord
  class Relation
    module Union
      # This is exclusive for a project
      def union_between(relation_or_where_arg_1,relation_or_where_arg_2,*args)
        other_1  = relation_or_where_arg_1 if args.size == 0 && Relation === relation_or_where_arg_1
        other_2  = relation_or_where_arg_2 if args.size == 0 && Relation === relation_or_where_arg_2
        other_1 ||= @klass.where(relation_or_where_arg_1, *args)
        other_2 ||= @klass.where(relation_or_where_arg_2, *args)

        # Postgres allows ORDER BY in the UNION subqueries if each subquery is surrounded by parenthesis
        # but SQLite does not allow parens around the subqueries; you will have to explicitly do `relation.reorder(nil)` in SQLite
        if Arel::Visitors::SQLite === self.visitor
          one, two, three = self.ast, other_1.ast, other_2.ast
        else
          one, two, three = Arel::Nodes::Grouping.new(self.ast), Arel::Nodes::Grouping.new(other_1.ast), Arel::Nodes::Grouping.new(other_2.ast)
        end

        union = Arel::Nodes::Union.new(one, Arel::Nodes::Union.new(two,three))

        # Turns out, I needed to change it even more, :P
        from = Arel::Nodes::TableAlias.new(
            union,
            Arel::Nodes::SqlLiteral.new(@klass.arel_table.name + "_union, " + @klass.arel_table.name)
        )

        relation = @klass.unscoped.select(@klass.arel_table.name + ".*, SUM(match_prc) AS match_prc").from(from)
        relation.bind_values = self.bind_values + other_1.bind_values + other_2.bind_values
        relation
      end

      def union(relation_or_where_arg,*args)
        other   = relation_or_where_arg if args.size == 0 && Relation === relation_or_where_arg
        other ||= @klass.where(relation_or_where_arg, *args)

        verify_union_relations!(self, other)

        # Postgres allows ORDER BY in the UNION subqueries if each subquery is surrounded by parenthesis
        # but SQLite does not allow parens around the subqueries; you will have to explicitly do `relation.reorder(nil)` in SQLite
        if Arel::Visitors::SQLite === self.visitor
          left, right = self.ast, other.ast
        else
          left, right = Arel::Nodes::Grouping.new(self.ast), Arel::Nodes::Grouping.new(other.ast)
        end

        union = Arel::Nodes::Union.new(left, Arel::Nodes::Union.new(left,right))
        from = Arel::Nodes::TableAlias.new(
            union,
            Arel::Nodes::SqlLiteral.new(@klass.arel_table.name + "_union, " + @klass.arel_table.name)
        )

        relation = @klass.unscoped.from(from)
        relation.bind_values = self.bind_values + other.bind_values
        relation
      end

      private

      def verify_union_relations!(*args)
        includes_relations = args.select { |r| r.includes_values.any? }
        if includes_relations.any?
          raise ArgumentError.new("Cannot union relation with includes.")
        end

        preload_relations = args.select { |r| r.preload_values.any? }
        if preload_relations.any?
          raise ArgumentError.new("Cannot union relation with preload.")
        end

        eager_load_relations = args.select { |r| r.eager_load_values.any? }
        if eager_load_relations.any?
          raise ArgumentError.new("Cannot union relation with eager load.")
        end
      end
    end
  end
end
