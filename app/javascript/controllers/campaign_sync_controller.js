import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "publishErrorAlert",
    "publishErrorMsg",
    "publishSubmitBtn",
    "resyncErrorAlert",
    "resyncErrorMsg"
  ]

  static values = {
    campaignId: Number,
    syncingText: { type: String, default: "" },
    syncToPlatformText: { type: String, default: "" },
    resyncText: { type: String, default: "" },
    selectAccountError: { type: String, default: "" },
    failedText: { type: String, default: "" },
    serverErrorText: { type: String, default: "" }
  }

  get authHeaders() {
    const token = document.querySelector('meta[name="auth-token"]')?.content
    const headers = {
      "Content-Type": "application/json",
      "Accept": "application/json"
    }
    if (token) {
      headers["Authorization"] = `Bearer ${token}`
    }
    return headers
  }

  async publish(event) {
    if (event) event.preventDefault()

    this.hidePublishError()

    const form = event.currentTarget
    const checked = Array.from(form.querySelectorAll('input[name="platform_account_ids[]"]:checked'))

    if (checked.length === 0) {
      this.showPublishError(this.selectAccountErrorValue)
      return
    }

    const submitBtn = this.hasPublishSubmitBtnTarget ? this.publishSubmitBtnTarget : form.querySelector('button[type="submit"]')
    const originalBtnHtml = submitBtn ? submitBtn.innerHTML : null

    if (submitBtn) {
      submitBtn.disabled = true
      submitBtn.innerHTML = `<span>${this.syncingTextValue}</span>`
    }

    const accountIds = checked.map(el => parseInt(el.value, 10))
    const platform = checked[0].dataset.platform || "facebook"
    const campaignId = this.campaignIdValue || form.dataset.campaignId

    try {
      const response = await fetch(`/api/v1/${platform}/campaigns/${campaignId}/publish`, {
        method: "POST",
        headers: this.authHeaders,
        body: JSON.stringify({ platform_account_ids: accountIds })
      })

      const data = await response.json()
      if (!response.ok || !data.success) {
        if (submitBtn) {
          submitBtn.disabled = false
          submitBtn.innerHTML = originalBtnHtml || `<span>${this.syncToPlatformTextValue}</span>`
        }
        const errs = data.errors || this.failedTextValue
        this.showPublishError(typeof errs === "object" ? JSON.stringify(errs) : String(errs))
      }
      // If success, Turbo Streams channel replaces sections in real-time
    } catch (err) {
      if (submitBtn) {
        submitBtn.disabled = false
        submitBtn.innerHTML = originalBtnHtml || `<span>${this.syncToPlatformTextValue}</span>`
      }
      this.showPublishError(`${this.serverErrorTextValue}: ${err.message}`)
    }
  }

  async resync(event) {
    if (event) event.preventDefault()

    const btn = event.currentTarget
    if (!btn || btn.disabled) return

    this.hideResyncError()

    const platform = btn.dataset.platform
    const campaignId = btn.dataset.campaignId || this.campaignIdValue
    const pcId = parseInt(btn.dataset.platformCampaignId, 10)

    // Optimistic UI: Immediately hide the resync button and set status badge to pending (pulse)
    const row = btn.closest("tr") || document.getElementById(`platform_campaign_row_${pcId}`)
    const statusCell = row?.querySelector("td:nth-child(4)")
    const actionCell = row?.querySelector("td:nth-child(5)")
    const originalStatusHtml = statusCell ? statusCell.innerHTML : null
    const originalActionHtml = actionCell ? actionCell.innerHTML : null

    if (actionCell) {
      actionCell.innerHTML = ""
    }
    if (statusCell) {
      statusCell.innerHTML = `
        <div class="flex items-center space-x-2">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-100 text-blue-800 border border-blue-200">
            <span class="w-1.5 h-1.5 mr-1.5 bg-blue-500 rounded-full animate-pulse"></span>
            ${this.syncingTextValue}
          </span>
        </div>
      `
    }

    try {
      const response = await fetch(`/api/v1/${platform}/campaigns/${campaignId}/resync`, {
        method: "POST",
        headers: this.authHeaders,
        body: JSON.stringify({ platform_campaign_id: pcId })
      })

      const data = await response.json()
      if (!response.ok || !data.success) {
        if (actionCell && originalActionHtml) actionCell.innerHTML = originalActionHtml
        if (statusCell && originalStatusHtml) statusCell.innerHTML = originalStatusHtml
        const errs = data.errors || this.failedTextValue
        this.showResyncError(typeof errs === "object" ? JSON.stringify(errs) : String(errs))
      }
      // If success, Turbo Streams channel replaces sections in real-time
    } catch (err) {
      if (actionCell && originalActionHtml) actionCell.innerHTML = originalActionHtml
      if (statusCell && originalStatusHtml) statusCell.innerHTML = originalStatusHtml
      this.showResyncError(`${this.serverErrorTextValue}: ${err.message}`)
    }
  }

  showPublishError(msg) {
    if (this.hasPublishErrorAlertTarget && this.hasPublishErrorMsgTarget) {
      this.publishErrorMsgTarget.textContent = msg
      this.publishErrorAlertTarget.classList.remove("hidden")
    }
  }

  hidePublishError() {
    if (this.hasPublishErrorAlertTarget && this.hasPublishErrorMsgTarget) {
      this.publishErrorAlertTarget.classList.add("hidden")
      this.publishErrorMsgTarget.textContent = ""
    }
  }

  showResyncError(msg) {
    if (this.hasResyncErrorAlertTarget && this.hasResyncErrorMsgTarget) {
      this.resyncErrorMsgTarget.textContent = msg
      this.resyncErrorAlertTarget.classList.remove("hidden")
    }
  }

  hideResyncError() {
    if (this.hasResyncErrorAlertTarget && this.hasResyncErrorMsgTarget) {
      this.resyncErrorAlertTarget.classList.add("hidden")
      this.resyncErrorMsgTarget.textContent = ""
    }
  }
}
