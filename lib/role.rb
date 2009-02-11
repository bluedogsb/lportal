class Role < ActiveRecord::Base
  set_table_name       :role_
  set_primary_key      :roleid

  validates_uniqueness_of :name, :scope => 'companyid'

  # com.liferay.portal.model.Role
  def liferay_class
    'com.liferay.portal.model.Role'
  end

  # Actions for Permissions.
  def self.actions
    %w{
      ASSIGN_MEMBERS
      DEFINE_PERMISSIONS
      DELETE
      MANAGE_ANNOUNCEMENTS
      PERMISSIONS
      UPDATE
      VIEW
    }
  end

  # Creates a new role.
  #
  # This process is engineered by creating a new role with Liferay's (v. 5.1.1) tools and
  # inspecting the database dump diffs.
  #
  # Mandatory parameters:
  #  - companyid
  #  - name
  def initialize(params)
    raise 'No companyid given' unless (params[:companyid] or params[:company])
    raise 'No name given' unless params[:name]

    super(params)

    # COPY role_ (roleid, companyid, classnameid, classpk, name, description, type_) FROM stdin;
    # +10151	10109	0	0	Regular role	This role is a test	1

    self.classnameid ||= 0
    self.classpk     ||= 0
    self.description ||= ''
    # Type: 1 = regular, 2 = community, 3 = organization
    self.type_       ||= 1

    self.save

    # Resource with code scope 1 is primkey'd to company.
    # Resource with code scope 4 is primkey'd to this role.

    # These are created regardless of what type_ is.

    # COPY resourcecode (codeid, companyid, name, scope) FROM stdin;
    # +29	10109	com.liferay.portal.model.Role	1
    # +30	10109	com.liferay.portal.model.Role	4

    [1,4].each do |scope|
      rc = self.resource_code(scope)
      unless rc
        ResourceCode.create(
          :companyid => self.companyid,
          :name      => self.liferay_class,
          :scope     => scope
        )
      end
    end

    # COPY resource_ (resourceid, codeid, primkey) FROM stdin;
    # +33	29	10109
    # +34	30	10151

    rc = self.resource_code(1)
    raise 'Required ResourceCode not found' unless rc
    r = Resource.find(:first, :conditions => "codeid=#{rc.id} AND primkey='#{self.companyid}'")
    unless r
      Resource.create(
        :codeid  => rc.id,
        :primkey => self.companyid
      )
    end

    rc = self.resource_code(4)
    raise 'Required ResourceCode not found' unless rc
    r = Resource.create(
      :codeid  => rc.id,
      :primkey => self.id
    )

    # Permissions (given to administrators)

    #  COPY permission_ (permissionid, companyid, actionid, resourceid) FROM stdin;
    # +70     10109   ASSIGN_MEMBERS  34
    # +71     10109   DEFINE_PERMISSIONS      34
    # +72     10109   DELETE  34
    # +73     10109   MANAGE_ANNOUNCEMENTS    34
    # +74     10109   PERMISSIONS     34
    # +75     10109   UPDATE  34
    # +76     10109   VIEW    34

    # COPY users_permissions (userid, permissionid) FROM stdin;
    # +10129	70
    # +10129	71
    # +10129	72
    # +10129	73
    # +10129	74
    # +10129	75
    # +10129	76

    self.class.actions.each do |actionid|
      p = Permission.create(
        :companyid  => self.companyid,
        :actionid   => actionid,
        :resourceid => r.id
      )
      self.company.administrators.each do |user|
        user.user_permissions << p
      end
    end
  end

  def destroy_without_callbacks
    unless new_record?
      rc = self.resource_code(4)
      if rc
        r = Resource.find(:first, :conditions => "codeid=#{rc.id} AND primkey='#{self.id}'")
        if r
          self.class.actions.each do |actionid|
            p = Permission.find(:first,
              :conditions => "companyid=#{self.companyid} AND actionid='#{actionid}' AND resourceid=#{r.id}")
            next unless p
            p.users.each do |user|
              user.user_permissions.delete(p)
            end
            p.groups.each do |group|
              group.permissions.delete(p)
            end
            p.destroy
          end
          r.destroy
        end
        rc.destroy
      end

      self.users.each do |user|
        user.roles.delete(self)
      end

      self.groups.each do |group|
        group.roles.delete(self)
      end

      super

    end
    freeze
  end



  belongs_to :company,
    :foreign_key => "companyid"

  has_and_belongs_to_many :permissions,
    :join_table              => "roles_permissions",
    :foreign_key             => "roleid",
    :association_foreign_key => "permissionid"

  # association to users
  has_and_belongs_to_many  :users,
                           :join_table              => "users_roles",
                           :foreign_key             => "roleid",
                           :association_foreign_key => "userid"

  # association to users
  has_and_belongs_to_many  :groups,
                           :join_table              => "groups_roles",
                           :foreign_key             => "roleid",
                           :association_foreign_key => "groupid"

  # ResourceCode associated to this instance (and scope)
  def resource_code(scope=4)
    ResourceCode.find(:first,
      :conditions => "companyid=#{self.companyid} AND name='#{self.liferay_class}' AND scope=#{scope}")
  end

end