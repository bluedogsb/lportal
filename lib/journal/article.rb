module Journal
  class Article < ActiveRecord::Base
    set_table_name       :journalarticle
    set_primary_key      :id_

    # com.liferay.portlet.journal.model.JournalArticle
    def liferay_class
      'com.liferay.portlet.journal.model.JournalArticle'
    end

    belongs_to :company,
      :foreign_key => 'companyid'

    belongs_to :group,
      :foreign_key => 'groupid'

    # association to user
    belongs_to :user,
      :foreign_key => 'userid'
    alias :owner :user

    belongs_to :resource,
      :class_name => 'Journal::ArticleResource',
      :foreign_key => 'resourceprimkey'

    def asset
      self.resource.asset
    end

    has_many :properties,
      :class_name => 'TagsProperty',
      :foreign_key => 'entryid'

#     # association to assets
#     has_and_belongs_to_many  :assets,
#       :join_table              => 'tagsassets_tagsentries',
#       :foreign_key             => 'entryid',
#       :association_foreign_key => 'assetid'


  end

end