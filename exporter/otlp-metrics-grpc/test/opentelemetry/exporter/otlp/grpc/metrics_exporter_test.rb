# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0
require 'test_helper'

describe OpenTelemetry::Exporter::OTLP::GRPC::MetricsExporter do
  let(:success) { OpenTelemetry::SDK::Metrics::Export::SUCCESS }

  describe '#exporter' do
    it 'integrates with collector' do
      # skip unless ENV['TRACING_INTEGRATION_TEST']
      metric_data = create_metrics_data
      exporter = OpenTelemetry::Exporter::OTLP::GRPC::MetricsExporter.new(endpoint: 'http://localhost:4317')
      result = exporter.export([metric_data])
      _(result).must_equal(success)
    end
  end
end
