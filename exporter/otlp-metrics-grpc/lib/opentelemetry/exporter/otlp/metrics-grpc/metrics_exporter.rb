# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry/common'

require 'google/rpc/status_pb'
require 'grpc'

require 'opentelemetry/proto/common/v1/common_pb'
require 'opentelemetry/proto/resource/v1/resource_pb'
require 'opentelemetry/proto/metrics/v1/metrics_pb'
require 'opentelemetry/proto/collector/metrics/v1/metrics_service_services_pb'

require 'opentelemetry/metrics'
require 'opentelemetry/sdk/metrics'

require_relative './util'

module OpenTelemetry
  module Exporter
    module OTLP
      module GRPC
        # An OpenTelemetry metrics exporter that sends metrics over HTTP as Protobuf encoded OTLP ExportMetricsServiceRequest.
        class MetricsExporter < ::OpenTelemetry::SDK::Metrics::Export::MetricReader # rubocop:disable Metrics/ClassLength
          include Util

          attr_reader :metric_snapshots

          SUCCESS = OpenTelemetry::SDK::Metrics::Export::SUCCESS
          FAILURE = OpenTelemetry::SDK::Metrics::Export::FAILURE
          private_constant(:SUCCESS, :FAILURE)

          def initialize(endpoint: OpenTelemetry::Common::Utilities.config_opt('OTEL_EXPORTER_OTLP_METRICS_ENDPOINT', 'OTEL_EXPORTER_OTLP_ENDPOINT', default: 'http://localhost:4317/v1/metrics'),
                         timeout: OpenTelemetry::Common::Utilities.config_opt('OTEL_EXPORTER_OTLP_METRICS_TIMEOUT', 'OTEL_EXPORTER_OTLP_TIMEOUT', default: 10),
                         metrics_reporter: nil)
            raise ArgumentError, "invalid url for OTLP::GRPC::MetricsExporter #{endpoint}" unless OpenTelemetry::Common::Utilities.valid_url?(endpoint)

            # create the MetricStore object
            super()

            uri = URI(endpoint)

            @client = Opentelemetry::Proto::Collector::Metrics::V1::MetricsService::Stub.new(
              "#{uri.host}:#{uri.port}",
              :this_channel_is_insecure
            )

            @timeout = timeout.to_f
            @shutdown = false
          end

          # consolidate the metrics data into the form of MetricData
          #
          # return MetricData
          def pull
            export(collect)
          end

          # Called to export sampled {OpenTelemetry::SDK::Metrics::MetricData} structs.
          #
          # @param [Enumerable<OpenTelemetry::SDK::Metrics::MetricData>] span_data the
          #   list of recorded {OpenTelemetry::SDK::Metrics::MetricData} structs to be
          #   exported.
          # @param [optional Numeric] timeout An optional timeout in seconds.
          # @return [Integer] the result of the export.
          def export(metrics, timeout: nil)
            return FAILURE if @shutdown

            @client.export(encode(metrics))
            SUCCESS
          end

          # Called when {OpenTelemetry::SDK::Metrics::MeterProvider#force_flush} is called, if
          # this exporter is registered to a {OpenTelemetry::SDK::Metrics::MeterProvider}
          # object.
          #
          # @param [optional Numeric] timeout An optional timeout in seconds.
          def force_flush(timeout: nil)
            SUCCESS
          end

          # Called when {OpenTelemetry::SDK::Metrics::MeterProvider#shutdown} is called, if
          # this exporter is registered to a {OpenTelemetry::SDK::Metrics::MeterProvider}
          # object.
          #
          # @param [optional Numeric] timeout An optional timeout in seconds.
          def shutdown(timeout: nil)
            @shutdown = true
            SUCCESS
          end
        end
      end
    end
  end
end
