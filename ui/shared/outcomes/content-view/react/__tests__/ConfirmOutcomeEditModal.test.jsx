/*
 * Copyright (C) 2018 - present Instructure, Inc.
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
import React from 'react'
import ReactDOM from 'react-dom'
import {shallow} from 'enzyme'
import {merge} from 'lodash'
import ConfirmOutcomeEditModal, {showConfirmOutcomeEdit} from '../ConfirmOutcomeEditModal'
import Modal from '@canvas/instui-bindings/react/InstuiModal'

const defaultProps = (props = {}) =>
  merge(
    {
      changed: true,
      assessed: true,
      hasUpdateableRubrics: false,
      modifiedFields: {
        masteryPoints: false,
        scoringMethod: false,
      },
      parent: () => {},
      onConfirm: () => {},
    },
    props,
  )

it('renders the ConfirmOutcomeEditModal component', () => {
  const modal = shallow(<ConfirmOutcomeEditModal {...defaultProps({hasUpdateableRubrics: true})} />)
  expect(modal.exists()).toBe(true)
})

it('renders the rubrics text if hasUpdateableRubrics', () => {
  const modal = shallow(<ConfirmOutcomeEditModal {...defaultProps({hasUpdateableRubrics: true})} />)
  expect(modal.find(Modal.Body).render().text()).toMatch(/update all rubrics/)
})

it('renders the masteryPoints text if mastery points modified', () => {
  const modal = shallow(
    <ConfirmOutcomeEditModal {...defaultProps({modifiedFields: {masteryPoints: true}})} />,
  )
  expect(modal.find(Modal.Body).render().text()).toMatch(/scoring criteria/)
})

it('renders the scoring method text if scoring method modified', () => {
  const modal = shallow(
    <ConfirmOutcomeEditModal {...defaultProps({modifiedFields: {scoringMethod: true}})} />,
  )
  expect(modal.find(Modal.Body).render().text()).toMatch(/scoring criteria/)
})

it('does not call onConfirm when canceled', () => {
  const onConfirm = jest.fn()
  const modal = shallow(
    <ConfirmOutcomeEditModal {...defaultProps({hasUpdateableRubrics: true, onConfirm})} />,
  )
  modal.find(Modal.Footer).find('#cancel-outcome-edit-modal').simulate('click')
  expect(modal.state('show')).toBe(false)
  expect(onConfirm).not.toHaveBeenCalled()
})

it('calls onConfirm when saved', () => {
  const onConfirm = jest.fn()
  const modal = shallow(
    <ConfirmOutcomeEditModal {...defaultProps({hasUpdateableRubrics: true, onConfirm})} />,
  )

  jest.useFakeTimers()
  modal.find(Modal.Footer).find('#confirm-outcome-edit-modal').simulate('click')
  jest.runAllTimers()

  expect(modal.state('show')).toBe(false)
  expect(onConfirm).toHaveBeenCalled()
})

describe('showConfirmOutcomeEdit', () => {
  afterEach(() => {
    const parent = document.querySelector('.confirm-outcome-edit-modal-container')
    if (parent) {
      const skipScroll = jest.spyOn(window, 'scroll').mockImplementation(() => {})
      ReactDOM.unmountComponentAtNode(parent)
      parent.remove()
      skipScroll.mockRestore()
    }
  })

  const doesNotRenderFor = props => {
    const onConfirm = jest.fn()

    jest.useFakeTimers()
    showConfirmOutcomeEdit({...props, onConfirm})
    jest.runAllTimers()

    expect(onConfirm).toHaveBeenCalled()
    expect(document.querySelector('.confirm-outcome-edit-modal-container')).toBeNull()
  }

  const rendersFor = props => {
    const app = document.createElement('div')
    app.setAttribute('id', 'application')
    document.body.appendChild(app)

    const onConfirm = jest.fn()

    jest.useFakeTimers()
    showConfirmOutcomeEdit({...props, onConfirm})
    jest.runAllTimers()

    expect(onConfirm).not.toHaveBeenCalled()
    expect(document.querySelector('.confirm-outcome-edit-modal-container')).not.toBeNull()
  }

  it('does not render a dialog if nothing updateable and not modified', () => {
    doesNotRenderFor(defaultProps())
  })

  it('renders a dialog if has updateable rubrics', () => {
    rendersFor(defaultProps({hasUpdateableRubrics: true}))
  })

  it('does not render a dialog if not assessed', () => {
    doesNotRenderFor(defaultProps({assessed: false, modifiedFields: {masteryPoints: true}}))
  })

  it('renders a dialog if masteryPoints modified', () => {
    rendersFor(defaultProps({modifiedFields: {masteryPoints: true}}))
  })

  it('renders a dialog if scoringMethod modified', () => {
    rendersFor(defaultProps({modifiedFields: {scoringMethod: true}}))
  })

  it('does not render a dialog if unchanged', () => {
    doesNotRenderFor(defaultProps({changed: false}))
  })
})
