# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

module Api::V1::Folders
  include Api::V1::Json

  def folders_json(folders, user, session, opts = {})
    folders.map do |f|
      folder_json(f, user, session, opts)
    end
  end

  def folder_json(folder, user, session, opts = {})
    can_view_hidden_files = opts.key?(:can_view_hidden_files) ? opts[:can_view_hidden_files] : folder.grants_right?(user, :update)
    json = api_json(folder,
                    user,
                    session,
                    only: %w[id name full_name position parent_folder_id context_type context_id unlock_at lock_at created_at updated_at category])
    if folder
      if opts[:master_course_restricted_folder_ids]&.include?(folder.id)
        json["is_master_course_child_content"] = true
        json["restricted_by_master_course"] = true
      end
      json["locked"] = !!folder.locked
      json["all_url"] = api_v1_list_folders_and_files_url(folder) if Account.site_admin.feature_enabled?(:files_a11y_rewrite)
      json["folders_url"] = api_v1_list_folders_url(folder)
      json["files_url"] = api_v1_list_files_url(folder)
      json["files_count"] = can_view_hidden_files ? folder.active_file_attachments.size : folder.active_file_attachments.not_hidden.not_locked.size
      json["folders_count"] = can_view_hidden_files ? folder.active_sub_folders.size : folder.active_sub_folders.not_hidden.not_locked.size
      json["hidden"] = folder.hidden?
      json["locked_for_user"] = can_view_hidden_files ? false : !!folder.currently_locked
      json["hidden_for_user"] = can_view_hidden_files ? false : !!folder.hidden?
      json["for_submissions"] = folder.for_submissions?
      json["can_upload"] = folder.grants_right?(user, :manage_contents)
    end
    json
  end

  def folders_or_files_json(items, user, session, opts = {})
    items.map do |item|
      case item
      when Folder
        folder_json(item, user, session, opts)
      when Attachment
        attachment_json(item, user, {}, opts)
      end
    end
  end
end
