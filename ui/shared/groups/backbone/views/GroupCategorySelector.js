/*
 * Copyright (C) 2023 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import {extend} from '@canvas/backbone/utils'
import {useScope as createI18nScope} from '@canvas/i18n'
import Backbone from '@canvas/backbone'
import {isEmpty, find, chain, includes} from 'lodash'
import template from '../../jst/GroupCategorySelector.handlebars'
import '@canvas/assignments/jquery/toggleAccessibly'
import awaitElement from '@canvas/await-element'
import {renderCreateDialog} from '../../react/CreateOrEditSetModal'
import StudentGroupStore from '@canvas/due-dates/react/StudentGroupStore'

const I18n = createI18nScope('assignment_group_category')

extend(GroupCategorySelector, Backbone.View)

function GroupCategorySelector() {
  this._validateGroupCategoryID = this._validateGroupCategoryID.bind(this)
  this.validateBeforeSave = this.validateBeforeSave.bind(this)
  this.filterFormData = this.filterFormData.bind(this)
  this.toJSON = this.toJSON.bind(this)
  this.toggleGroupCategoryOptions = this.toggleGroupCategoryOptions.bind(this)
  this.clickGroupCategoryOptions = this.clickGroupCategoryOptions.bind(this)
  this.canManageGroups = this.canManageGroups.bind(this)
  this.enableGroupDiscussionCheckbox = this.enableGroupDiscussionCheckbox.bind(this)
  this.disableGroupDiscussionCheckbox = this.disableGroupDiscussionCheckbox.bind(this)
  this.groupDiscussionChecked = this.groupDiscussionChecked.bind(this)
  this.showGroupCategoryCreateDialog = this.showGroupCategoryCreateDialog.bind(this)
  this.groupCategorySelected = this.groupCategorySelected.bind(this)
  this.render = this.render.bind(this)
  return GroupCategorySelector.__super__.constructor.apply(this, arguments)
}

GroupCategorySelector.prototype.template = template

const GROUP_CATEGORY = '#assignment_group_category'
const GROUP_CATEGORY_ID = '#assignment_group_category_id'
const CREATE_GROUP_CATEGORY_ID = '#create_group_category_id'
const HAS_GROUP_CATEGORY = '#has_group_category'
const GROUP_CATEGORY_OPTIONS = '#group_category_options'
export const GROUP_CATEGORY_SELECT = 'assignment_group_category_id'

GroupCategorySelector.prototype.els = (function () {
  const els = {}
  els['' + GROUP_CATEGORY] = '$groupCategory'
  els['' + GROUP_CATEGORY_ID] = '$groupCategoryID'
  els['' + HAS_GROUP_CATEGORY] = '$hasGroupCategory'
  els['' + GROUP_CATEGORY_OPTIONS] = '$groupCategoryOptions'
  return els
})()

GroupCategorySelector.prototype.events = (function () {
  const events = {}
  events['change ' + GROUP_CATEGORY_ID] = 'handleSelectOption'
  events['click ' + CREATE_GROUP_CATEGORY_ID] = 'showGroupCategoryCreateDialog'
  events['change ' + HAS_GROUP_CATEGORY] = 'toggleGroupCategoryOptions'
  events['click ' + HAS_GROUP_CATEGORY] = 'clickGroupCategoryOptions'
  return events
})()

GroupCategorySelector.prototype.initialize = function (options) {
  GroupCategorySelector.__super__.initialize.apply(this, arguments)
  this.showNewErrors = options.showNewErrors
  return (this.renderSectionsAutocomplete = options.renderSectionsAutocomplete)
}

GroupCategorySelector.optionProperty('parentModel')

GroupCategorySelector.optionProperty('groupCategories')

GroupCategorySelector.optionProperty('nested')

GroupCategorySelector.optionProperty('hideGradeIndividually')

GroupCategorySelector.optionProperty('sectionLabel')

GroupCategorySelector.optionProperty('fieldLabel')

GroupCategorySelector.optionProperty('lockedMessage')

GroupCategorySelector.optionProperty('inClosedGradingPeriod')

GroupCategorySelector.prototype.render = function () {
  const selectedID = this.parentModel.groupCategoryId()
  if (isEmpty(this.groupCategories)) {
    StudentGroupStore.setSelectedGroupSet(null)
  } else if (
    selectedID == null ||
    find(this.groupCategories, {
      id: selectedID.toString(),
    }) == null
  ) {
    StudentGroupStore.setSelectedGroupSet(null)
  } else {
    StudentGroupStore.setSelectedGroupSet(selectedID)
  }
  GroupCategorySelector.__super__.render.apply(this, arguments)
  if (this.showNewErrors) {
    const createGroupSetButton = document.getElementById('create_group_category_id')
    if (createGroupSetButton) createGroupSetButton.style.display = 'none'
  }
  return this.$groupCategory.toggleAccessibly(true)
}

GroupCategorySelector.prototype.handleSelectOption = function (e) {
  const selectedValue = e.target.value

  if (selectedValue === 'new') {
    this.showGroupCategoryCreateDialog()
  } else {
    this.groupCategorySelected()
  }
}

GroupCategorySelector.prototype.groupCategorySelected = function () {
  const selected_group_category_id = StudentGroupStore.getSelectedGroupSetId()
  const has_group_overrides = this.hasGroupOverrides(selected_group_category_id)
  const error_message = document.getElementById('assignment_group_category_id_blocked_error')
  if (has_group_overrides !== undefined) {
    this.$groupCategoryID.val(selected_group_category_id)
    error_message.innerText = I18n.t(
      'You must remove any groups belonging to %{group} from the Assign Access section before you can change to another Group Set.',
      {group: this.$groupCategoryID[0].options[this.$groupCategoryID[0].selectedIndex].text},
    )
    error_message.style.display = 'block'
    return
  }
  error_message.style.display = 'none'

  const newSelectedId = this.$groupCategoryID.val()
  StudentGroupStore.setSelectedGroupSet(newSelectedId)
  return document.dispatchEvent(new Event('group_category_changed'))
}

GroupCategorySelector.prototype.showGroupCategoryCreateDialog = function () {
  return awaitElement('create-group-set-modal-mountpoint')
    .then(renderCreateDialog)
    .then(
      (function (_this) {
        return function (result) {
          let $newCategory
          if (result) {
            $newCategory = document.createElement('option')
            $newCategory.value = result.id
            $newCategory.text = result.name
            $newCategory.setAttribute('selected', true)
            _this.$groupCategoryID.append($newCategory)
            _this.$groupCategoryID.val(result.id)
            _this.groupCategories.push(result)

            // Runs the validations and shows an error if there is
            // an group override that belongs to the previous group set
            _this.groupCategorySelected()

            return _this.$groupCategory.toggleAccessibly(true)
          } else {
            const blankOption = document.querySelector('[value="blank"]')
            const select = blankOption.parentElement
            select.value = blankOption.value
          }
        }
      })(this),
    )
}

GroupCategorySelector.prototype.groupDiscussionChecked = function () {
  return this.$hasGroupCategory.prop('checked')
}

GroupCategorySelector.prototype.disableGroupDiscussionCheckbox = function () {
  return this.$hasGroupCategory.prop('disabled', true)
}

GroupCategorySelector.prototype.enableGroupDiscussionCheckbox = function () {
  return this.$hasGroupCategory.prop('disabled', false)
}

GroupCategorySelector.prototype.canManageGroups = function () {
  let ref
  if ((ref = ENV.PERMISSIONS) != null ? ref.hasOwnProperty('can_manage_groups') : void 0) {
    return ENV.PERMISSIONS.can_manage_groups
  } else {
    return true
  }
}

GroupCategorySelector.prototype.toggleGroupCategoryOptions = function () {
  const isGrouped = this.groupDiscussionChecked()
  this.$groupCategoryOptions.toggleAccessibly(isGrouped)
  const selectedGroupSetId = isGrouped ? this.$groupCategoryID.val() : null
  StudentGroupStore.setSelectedGroupSet(selectedGroupSetId)
  document.dispatchEvent(new Event('group_category_changed'))
  if (isGrouped && isEmpty(this.groupCategories) && this.canManageGroups()) {
    this.showGroupCategoryCreateDialog()
  }
  if (this.renderSectionsAutocomplete != null) {
    return this.renderSectionsAutocomplete()
  }
}

GroupCategorySelector.prototype.clickGroupCategoryOptions = function (e) {
  const selected_group_category_id = StudentGroupStore.getSelectedGroupSetId()
  const has_group_overrides = this.hasGroupOverrides(selected_group_category_id)
  const error_message = document.getElementById('has_group_category_blocked_error')
  if (has_group_overrides !== undefined) {
    e.preventDefault()
    e.stopPropagation()
    error_message.style.display = 'block'
    return
  }
  error_message.style.display = 'none'
}

GroupCategorySelector.prototype.toJSON = function () {
  let base
  const frozenAttributes =
    (typeof (base = this.parentModel).frozenAttributes === 'function'
      ? base.frozenAttributes()
      : void 0) || []
  const groupCategoryFrozen = includes(frozenAttributes, 'group_category_id')
  const groupCategoryLocked = !this.parentModel.canGroup()
  return {
    isGroupAssignment:
      this.parentModel.groupCategoryId() &&
      this.parentModel.groupCategoryId() !== 'blank' &&
      this.parentModel.groupCategoryId() !== 'new',
    groupCategoryId: this.parentModel.groupCategoryId(),
    groupCategories: this.groupCategories,
    groupCategoryUnselected:
      !this.parentModel.groupCategoryId() ||
      this.parentModel.groupCategoryId() === 'blank' ||
      this.parentModel.groupCategoryId() === 'new' ||
      (!chain(this.groupCategories)
        .map('id')
        .includes(this.parentModel.groupCategoryId().toString())
        .value() &&
        !isEmpty(this.groupCategories)),
    hideGradeIndividually: this.hideGradeIndividually,
    gradeGroupStudentsIndividually:
      !this.hideGradeIndividually && this.parentModel.gradeGroupStudentsIndividually(),
    groupCategoryLocked,
    hasGroupCategoryDisabled: groupCategoryFrozen || groupCategoryLocked,
    gradeIndividuallyDisabled: groupCategoryFrozen,
    groupCategoryIdDisabled: groupCategoryFrozen || groupCategoryLocked,
    sectionLabel: this.sectionLabel,
    fieldLabel: this.fieldLabel,
    lockedMessage: this.lockedMessage,
    nested: this.nested,
    prefix: this.nested ? 'assignment' : void 0,
    inClosedGradingPeriod: this.inClosedGradingPeriod,
    cannotManageGroups: !this.canManageGroups(),
  }
}

GroupCategorySelector.prototype.filterFormData = function (data) {
  const hasGroupCategory = data.has_group_category
  delete data.has_group_category
  if (hasGroupCategory === '0') {
    data.group_category_id = null
    data.grade_group_students_individually = false
  }
  return data
}

GroupCategorySelector.prototype.fieldSelectors = (function () {
  const s = {}
  s.groupCategorySelector = '#assignment_group_category_id'
  s.newGroupCategory = '#create_group_category_id'
  return s
})()

GroupCategorySelector.prototype.validateBeforeSave = function (data, errors) {
  errors = this._validateGroupCategoryID(data, errors)
  return errors
}

GroupCategorySelector.prototype._validateGroupCategoryID = function (data, errors) {
  const gcid = this.nested ? data.assignment.groupCategoryId() : data.group_category_id
  if (gcid === 'blank' || gcid === 'new') {
    if (isEmpty(this.groupCategories)) {
      if (this.canManageGroups()) {
        errors[this.showNewErrors ? GROUP_CATEGORY_SELECT : 'newGroupCategory'] = [
          {
            message: I18n.t('Please create a group set'),
          },
        ]
      } else {
        errors[this.showNewErrors ? GROUP_CATEGORY_SELECT : 'newGroupCategory'] = [
          {
            message: I18n.t('Group Add permission is needed to create a New Group Category'),
          },
        ]
      }
    } else {
      errors[GROUP_CATEGORY_SELECT] = [
        {
          message: I18n.t('Please select a group set for this assignment'),
        },
      ]
    }
  }
  return errors
}

GroupCategorySelector.prototype.hasGroupOverrides = function (selected_group_category_id) {
  if (!selected_group_category_id) return undefined
  return this.parentModel?.attributes?.assignment_overrides?.models?.find(
    override => override.attributes.group_category_id === selected_group_category_id,
  )
}

export default GroupCategorySelector
