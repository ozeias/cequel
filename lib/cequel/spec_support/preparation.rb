module Cequel
  module SpecSupport
    # Provide database preparation behavior that is useful for
    # spec/test suites.
    #
    # For Rails apps adding the following code to the bottom of one's
    # `spec_helper.rb` (below the `RSpec.configure` block) ensures a
    # clean and fully synced test db before each test run.
    #
    #     # one time database setup
    #     Cequel::SpecSupport::Preparation.setup_database
    #
    # For non-rails apps adding the following code to the bottom of
    # one's `spec_helper.rb` (below the `RSpec.configure` block)
    # ensures a clean and fully synced test db before each test run.
    #
    #     # one time database setup
    #     Cequel::SpecSupport::Preparation
    #       .setup_database(App.root + "lib/models",
    #                       App.root + "lib/other-models")
    class Preparation

      # Provision and sync the database for a spec run.
      #
      # @param [Array<String,Pathname>] model_dirs directories in
      #   which Cequel record classes reside. All files in these
      #   directories will be loaded before syncing the
      #   schema. Default: `Rails.root + "app/model"` if `Rails` is
      #   defined; otherwise no models will be autoloaded.
      def self.setup_database(*model_dirs)
        model_dirs = if model_dirs.any?
                       model_dirs.flatten

                     elsif defined? Rails
                       [Rails.root + "app/models"]

                     else
                       []
                     end

        prep = new(model_dirs)

        prep.drop_keyspace
        prep.create_keyspace
        prep.sync_schema
      end

      def initialize(model_dirs=[])
        @model_dirs = model_dirs
      end

      # Ensure the current keyspace does not exist.
      #
      # @return [Preparation] self
      def drop_keyspace
        keyspace = Cequel::Record.connection.schema

        keyspace.drop! if keyspace.exists?

        self
      end

      # Ensure that the necessary keyspace exists.
      #
      # @return [Preparation] self
      def create_keyspace
        keyspace = Cequel::Record.connection.schema

        keyspace.create! unless keyspace.exists?

        self
      end

      # Ensure that the necessary column families exist and match the
      # models.
      #
      # @return [Preparation] self
      def sync_schema
        record_classes.each do |a_record_class|
          begin
            a_record_class.synchronize_schema
            puts "Synchronized schema for #{a_record_class.name}"

          rescue Record::MissingTableNameError
            # It is obviously not a real record class if it doesn't have a table name.
            puts "Skipping anonymous record class w/o an explicit table name"
          rescue WeakRef::RefError
            # Stale ref... just skip it
          end
        end

        self
      end

      protected

      attr_reader :model_dirs

      # @return [Array<Class>] all Cequel record classes
      def record_classes
        load_all_models
        Cequel::Record.descendants
      end

      # Loads all files in the models directory under the assumption
      # that Cequel record classes live there.
      def load_all_models
        model_dirs.each do |a_directory|
          Dir.glob(Pathname(a_directory).join("**", "*.rb")).each do |file_name|
            require_dependency(file_name)
          end
        end
      end
    end
  end
end
