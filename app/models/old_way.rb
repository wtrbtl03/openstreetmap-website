# == Schema Information
#
# Table name: ways
#
#  way_id       :bigint(8)        default(0), not null, primary key
#  changeset_id :bigint(8)        not null
#  timestamp    :datetime         not null
#  version      :bigint(8)        not null, primary key
#  visible      :boolean          default(TRUE), not null
#  redaction_id :integer
#
# Indexes
#
#  ways_changeset_id_idx  (changeset_id)
#  ways_timestamp_idx     (timestamp)
#
# Foreign Keys
#
#  ways_changeset_id_fkey  (changeset_id => changesets.id)
#  ways_redaction_id_fkey  (redaction_id => redactions.id)
#

class OldWay < ApplicationRecord
  include ConsistencyValidations

  self.table_name = "ways"
  self.primary_keys = "way_id", "version"

  # NOTE: this needs to be included after the table name changes, or
  # the queries generated by Redactable will use the wrong table name.
  include Redactable

  belongs_to :changeset
  belongs_to :redaction
  belongs_to :current_way, :class_name => "Way", :foreign_key => "way_id", :inverse_of => :old_ways

  has_many :old_nodes, :class_name => "OldWayNode", :foreign_key => [:way_id, :version], :inverse_of => :old_way
  has_many :old_tags, :class_name => "OldWayTag", :foreign_key => [:way_id, :version], :inverse_of => :old_way

  validates :changeset, :presence => true, :associated => true
  validates :timestamp, :presence => true
  validates :visible, :inclusion => [true, false]

  def self.from_way(way)
    old_way = OldWay.new
    old_way.visible = way.visible
    old_way.changeset_id = way.changeset_id
    old_way.timestamp = way.timestamp
    old_way.way_id = way.id
    old_way.version = way.version
    old_way.nds = way.nds
    old_way.tags = way.tags
    old_way
  end

  def save_with_dependencies!
    save!

    tags.each do |k, v|
      tag = OldWayTag.new
      tag.k = k
      tag.v = v
      tag.way_id = way_id
      tag.version = version
      tag.save!
    end

    sequence = 1
    nds.each do |n|
      nd = OldWayNode.new
      nd.id = [way_id, version, sequence]
      nd.node_id = n
      nd.save!
      sequence += 1
    end
  end

  def nds
    @nds ||= old_nodes.order(:sequence_id).collect(&:node_id)
  end

  def tags
    @tags ||= old_tags.to_h { |t| [t.k, t.v] }
  end

  attr_writer :nds, :tags

  # Temporary method to match interface to ways
  def way_nodes
    old_nodes
  end

  # Pretend we're not in any relations
  def containing_relation_members
    []
  end

  # check whether this element is the latest version - that is,
  # has the same version as its "current" counterpart.
  def is_latest_version?
    current_way.version == version
  end
end
