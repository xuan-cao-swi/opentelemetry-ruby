# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Metrics
    # No-op implementation of Meter.
    class Meter
      COUNTER = Instrument::Counter.new
      OBSERVABLE_COUNTER = Instrument::ObservableCounter.new
      HISTOGRAM = Instrument::Histogram.new
      GAUGE = Instrument::Gauge.new
      OBSERVABLE_GAUGE = Instrument::ObservableGauge.new
      UP_DOWN_COUNTER = Instrument::UpDownCounter.new
      OBSERVABLE_UP_DOWN_COUNTER = Instrument::ObservableUpDownCounter.new

      NAME_REGEX = /\A[a-zA-Z][-.\w]{0,62}\z/

      private_constant(:COUNTER, :OBSERVABLE_COUNTER, :HISTOGRAM, :GAUGE, :OBSERVABLE_GAUGE, :UP_DOWN_COUNTER, :OBSERVABLE_UP_DOWN_COUNTER)

      DuplicateInstrumentError = Class.new(OpenTelemetry::Error)
      InstrumentNameError = Class.new(OpenTelemetry::Error)
      InstrumentUnitError = Class.new(OpenTelemetry::Error)
      InstrumentDescriptionError = Class.new(OpenTelemetry::Error)

      def initialize
        @mutex = Mutex.new
        @instrument_registry = {}
      end

      def create_counter(name, unit: nil, description: nil)
        create_instrument(:counter, name, unit, description, nil) { COUNTER }
      end

      def create_histogram(name, unit: nil, description: nil)
        create_instrument(:histogram, name, unit, description, nil) { HISTOGRAM }
      end

      # Gauge is an synchronous Instrument which reports non-additive value(s)
      #
      # With this api call:
      #
      #   meter.create_gauge("cpu.frequency",
      #                       description: "the real-time CPU clock speed",
      #                       unit: "ms")
      #
      #
      # @param name [String] the name of the gauge.
      # @param unit [optional String] an optional string provided by user.
      # @param description [optional String] an optional free-form text provided by user.
      #
      # @return [nil] after creation of gauge, it will be stored in instrument_registry
      def create_gauge(name, unit: nil, description: nil)
        create_instrument(:gauge, name, unit, description, nil) { GAUGE }
      end

      def create_up_down_counter(name, unit: nil, description: nil)
        create_instrument(:up_down_counter, name, unit, description, nil) { UP_DOWN_COUNTER }
      end

      def create_observable_counter(name, callback:, unit: nil, description: nil)
        create_instrument(:observable_counter, name, unit, description, callback) { OBSERVABLE_COUNTER }
      end

      def create_observable_gauge(name, callback:, unit: nil, description: nil)
        create_instrument(:observable_gauge, name, unit, description, callback) { OBSERVABLE_GAUGE }
      end

      def create_observable_up_down_counter(name, callback:, unit: nil, description: nil)
        create_instrument(:observable_up_down_counter, name, unit, description, callback) { OBSERVABLE_UP_DOWN_COUNTER }
      end

      private

      def create_instrument(kind, name, unit, description, callback)
        @mutex.synchronize do
          OpenTelemetry.logger.warn("duplicate instrument registration occurred for instrument #{name}") if @instrument_registry.include? name

          @instrument_registry[name] = yield
        end
      end
    end
  end
end
