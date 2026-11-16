# frozen_string_literal: true

require 'voxpupuli/test/spec_helper'
require 'webmock/rspec'

# Unit tests never talk to a real cluster.
WebMock.disable_net_connect!
