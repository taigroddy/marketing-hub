import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "errorAlert",
    "errorList",
    "submitBtn",
    "nameInput",
    "objectiveSelect",
    "budgetInput"
  ]

  static values = {
    url: { type: String, default: "" },
    method: { type: String, default: "POST" },
    submittingText: { type: String, default: "" },
    submitBtnText: { type: String, default: "" },
    failedText: { type: String, default: "" },
    networkErrorText: { type: String, default: "" },
    redirectUrl: { type: String, default: "" }
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

  async submit(event) {
    if (event) event.preventDefault()

    this.hideErrors()

    const submitBtn = this.hasSubmitBtnTarget ? this.submitBtnTarget : null
    const originalText = submitBtn ? submitBtn.textContent : ""

    if (submitBtn) {
      submitBtn.disabled = true
      if (this.submittingTextValue) {
        submitBtn.textContent = this.submittingTextValue
      }
    }

    const payload = {}
    if (this.hasNameInputTarget) {
      payload.name = this.nameInputTarget.value.trim()
    }
    if (this.hasObjectiveSelectTarget) {
      payload.objective = this.objectiveSelectTarget.value
    }
    if (this.hasBudgetInputTarget) {
      payload.budget = parseFloat(this.budgetInputTarget.value)
    }

    try {
      const response = await fetch(this.urlValue, {
        method: this.methodValue.toUpperCase(),
        headers: this.authHeaders,
        body: JSON.stringify(payload)
      })

      const data = await response.json()

      if (response.ok && data.success) {
        if (this.redirectUrlValue) {
          window.location.href = this.redirectUrlValue
        } else {
          const campaignId = data.data?.campaign?.id
          window.location.href = campaignId ? `/campaigns/${campaignId}` : "/dashboard"
        }
      } else {
        if (submitBtn) {
          submitBtn.disabled = false
          submitBtn.textContent = this.submitBtnTextValue || originalText
        }
        const errors = data.errors || { general: [this.failedTextValue] }
        this.showErrors(errors)
      }
    } catch (err) {
      if (submitBtn) {
        submitBtn.disabled = false
        submitBtn.textContent = this.submitBtnTextValue || originalText
      }
      this.showErrors(`${this.networkErrorTextValue} ${err.message || ""}`.trim())
    }
  }

  showErrors(errors) {
    if (this.hasErrorAlertTarget) {
      this.errorAlertTarget.classList.remove("hidden")
    }

    if (!this.hasErrorListTarget) return
    this.errorListTarget.innerHTML = ""

    if (typeof errors === "object" && !Array.isArray(errors)) {
      Object.entries(errors).forEach(([field, msgs]) => {
        const li = document.createElement("li")
        li.textContent = `${field}: ${Array.isArray(msgs) ? msgs.join(", ") : msgs}`
        this.errorListTarget.appendChild(li)
      })
    } else {
      const li = document.createElement("li")
      li.textContent = String(errors)
      this.errorListTarget.appendChild(li)
    }
  }

  hideErrors() {
    if (this.hasErrorAlertTarget) {
      this.errorAlertTarget.classList.add("hidden")
    }
    if (this.hasErrorListTarget) {
      this.errorListTarget.innerHTML = ""
    }
  }
}
