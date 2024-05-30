# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Exporter
    module OTLP
      module GRPC
        # Util module provide essential functionality for exporter
        module Util # rubocop:disable Metrics/ModuleLength
          def encode(metrics_data) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
            Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest.encode(
              Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest.new(
                resource_metrics: metrics_data
                  .group_by(&:resource)
                  .map do |resource, scope_metrics|
                    Opentelemetry::Proto::Metrics::V1::ResourceMetrics.new(
                      resource: Opentelemetry::Proto::Resource::V1::Resource.new(
                        attributes: resource.attribute_enumerator.map { |key, value| as_otlp_key_value(key, value) }
                      ),
                      scope_metrics: scope_metrics
                        .group_by(&:instrumentation_scope)
                        .map do |instrumentation_scope, metrics|
                          Opentelemetry::Proto::Metrics::V1::ScopeMetrics.new(
                            scope: Opentelemetry::Proto::Common::V1::InstrumentationScope.new(
                              name: instrumentation_scope.name,
                              version: instrumentation_scope.version
                            ),
                            metrics: metrics.map { |sd| as_otlp_metrics(sd) }
                          )
                        end
                    )
                  end
              )
            )
          rescue StandardError => e
            OpenTelemetry.handle_error(exception: e, message: 'unexpected error in OTLP::MetricsExporter#encode')
            nil
          end

          # metrics_pb has following type of data: :gauge, :sum, :histogram, :exponential_histogram, :summary
          # current metric sdk only implements instrument: :counter -> :sum, :histogram -> :histogram
          #
          # metrics [MetricData]
          def as_otlp_metrics(metrics) # rubocop:disable Metrics/MethodLength
            case metrics.instrument_kind
            when :observable_gauge
              Opentelemetry::Proto::Metrics::V1::Metric.new(
                name: metrics.name,
                description: metrics.description,
                unit: metrics.unit,
                gauge: Opentelemetry::Proto::Metrics::V1::Gauge.new(
                  aggregation_temporality: as_otlp_aggregation_temporality(metrics.aggregation_temporality),
                  data_points: metrics.data_points.map do |ndp|
                    number_data_point(ndp)
                  end
                )
              )

            when :counter, :up_down_counter
              Opentelemetry::Proto::Metrics::V1::Metric.new(
                name: metrics.name,
                description: metrics.description,
                unit: metrics.unit,
                sum: Opentelemetry::Proto::Metrics::V1::Sum.new(
                  aggregation_temporality: as_otlp_aggregation_temporality(metrics.aggregation_temporality),
                  data_points: metrics.data_points.map do |ndp|
                    number_data_point(ndp)
                  end
                )
              )

            when :histogram
              Opentelemetry::Proto::Metrics::V1::Metric.new(
                name: metrics.name,
                description: metrics.description,
                unit: metrics.unit,
                histogram: Opentelemetry::Proto::Metrics::V1::Histogram.new(
                  aggregation_temporality: as_otlp_aggregation_temporality(metrics.aggregation_temporality),
                  data_points: metrics.data_points.map do |hdp|
                    histogram_data_point(hdp)
                  end
                )
              )
            end
          end

          def as_otlp_aggregation_temporality(type)
            case type
            when :delta then Opentelemetry::Proto::Metrics::V1::AggregationTemporality::AGGREGATION_TEMPORALITY_DELTA
            when :cumulative then Opentelemetry::Proto::Metrics::V1::AggregationTemporality::AGGREGATION_TEMPORALITY_CUMULATIVE
            else Opentelemetry::Proto::Metrics::V1::AggregationTemporality::AGGREGATION_TEMPORALITY_UNSPECIFIED
            end
          end

          def histogram_data_point(hdp)
            Opentelemetry::Proto::Metrics::V1::HistogramDataPoint.new(
              attributes: hdp.attributes.map { |k, v| as_otlp_key_value(k, v) },
              start_time_unix_nano: hdp.start_time_unix_nano,
              time_unix_nano: hdp.time_unix_nano,
              count: hdp.count,
              sum: hdp.sum,
              bucket_counts: hdp.bucket_counts,
              explicit_bounds: hdp.explicit_bounds,
              exemplars: hdp.exemplars,
              min: hdp.min,
              max: hdp.max
            )
          end

          def number_data_point(ndp)
            Opentelemetry::Proto::Metrics::V1::NumberDataPoint.new(
              attributes: ndp.attributes.map { |k, v| as_otlp_key_value(k, v) },
              as_int: ndp.value,
              start_time_unix_nano: ndp.start_time_unix_nano,
              time_unix_nano: ndp.time_unix_nano,
              exemplars: ndp.exemplars # exemplars not implemented yet from metrics sdk
            )
          end

          def as_otlp_key_value(key, value)
            Opentelemetry::Proto::Common::V1::KeyValue.new(key: key, value: as_otlp_any_value(value))
          rescue Encoding::UndefinedConversionError => e
            encoded_value = value.encode('UTF-8', invalid: :replace, undef: :replace, replace: '�')
            OpenTelemetry.handle_error(exception: e, message: "encoding error for key #{key} and value #{encoded_value}")
            Opentelemetry::Proto::Common::V1::KeyValue.new(key: key, value: as_otlp_any_value('Encoding Error'))
          end

          def as_otlp_any_value(value)
            result = Opentelemetry::Proto::Common::V1::AnyValue.new
            case value
            when String
              result.string_value = value
            when Integer
              result.int_value = value
            when Float
              result.double_value = value
            when true, false
              result.bool_value = value
            when Array
              values = value.map { |element| as_otlp_any_value(element) }
              result.array_value = Opentelemetry::Proto::Common::V1::ArrayValue.new(values: values)
            end
            result
          end
        end
      end
    end
  end
end
