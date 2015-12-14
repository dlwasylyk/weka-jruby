require 'active_support/concern'
require 'weka/classifiers/evaluation'
require 'weka/core/instances'

module Weka
  module Classifiers
    module Utils
      extend ActiveSupport::Concern

      included do
        java_import 'java.util.Random'

        if instance_methods.include?(:build_classifier)
          attr_reader :training_instances

          def train_with_instances(instances)
            ensure_class_attribute_assigned!(instances)

            @training_instances = instances
            build_classifier(instances)

            self
          end

          def cross_validate(folds: 3)
            ensure_trained_with_instances!

            evaluation = Evaluation.new(training_instances)
            random     = Java::JavaUtil::Random.new(1)

            evaluation.cross_validate_model(self, training_instances, folds.to_i, random)
            evaluation
          end
        end

        if instance_methods.include?(:classify_instance)
          def classify(instance_or_values)
            ensure_trained_with_instances!

            instance = classifiable_instance_from(instance_or_values)
            index    = classify_instance(instance)

            class_value_of_index(index)
          end
        end

        if instance_methods.include?(:update_classifier)
          def add_training_instance(instance)
            training_instances.add(instance)
            update_classifier(instance)

            self
          end

          def add_training_data(data)
            values   = self.training_instances.internal_values_of(data)
            instance = Weka::Core::DenseInstance.new(values)
            add_training_instance(instance)
          end
        end

        if self.respond_to?(:__persistent__=)
          self.__persistent__ = true
        end

        private

        def ensure_class_attribute_assigned!(instances)
          return if instances.class_attribute_defined?

          error   = 'Class attribute is not assigned for Instances.'
          hint    = 'You can assign a class attribute with #class_attribute=.'
          message = "#{error} #{hint}"

          raise UnassignedClassError, message
        end

        def ensure_trained_with_instances!
          return unless training_instances.nil?

          error   = 'Classifier is not trained with Instances.'
          hint    = 'You can set the training instances with #train_with_instances.'
          message = "#{error} #{hint}"

          raise UnassignedTrainingInstancesError, message
        end

        def classifiable_instance_from(instance_or_values)
          attributes = training_instances.attributes
          instances  = Weka::Core::Instances.new(attributes: attributes)

          class_attribute = training_instances.class_attribute
          class_index     = training_instances.class_index
          instances.insert_attribute_at(class_attribute, class_index)

          instances.class_index = training_instances.class_index
          instances.add_instance(instance_or_values)

          instance = instances.first
          instance.set_class_missing
          instance
        end

        def class_value_of_index(index)
          training_instances.class_attribute.value(index)
        end
      end

    end
  end
end
