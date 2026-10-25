import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "footer",
    "errorAlert",
    "errorList",
    "successAlert",
    "successMsg",
    "submitBtn",
    "emailInput",
    "passwordInput",
    "passwordConfirmationInput"
  ]

  static values = {
    failedText: { type: String, default: "" },
    networkErrorText: { type: String, default: "" }
  }

  async submit(event) {
    if (event) event.preventDefault()

    this.hideError()
    if (this.hasSuccessAlertTarget) this.successAlertTarget.classList.add("hidden")
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = true

    const payload = {
      email: this.hasEmailInputTarget ? this.emailInputTarget.value.trim() : "",
      password: this.hasPasswordInputTarget ? this.passwordInputTarget.value : "",
      password_confirmation: this.hasPasswordConfirmationInputTarget ? this.passwordConfirmationInputTarget.value : ""
    }

    try {
      const response = await fetch("/api/v1/auth/register", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify(payload)
      })

      const data = await response.json()

      if (response.ok && data.success) {
        if (this.hasFormTarget) this.formTarget.classList.add("hidden")
        if (this.hasFooterTarget) this.footerTarget.classList.add("hidden")
        if (this.hasSuccessAlertTarget) {
          this.successAlertTarget.classList.remove("hidden")
          if (this.hasSuccessMsgTarget && data.data?.message) {
            this.successMsgTarget.textContent = data.data.message
          }
        }
      } else {
        if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = false
        const errors = data.errors || { general: [this.failedTextValue] }
        this.showErrors(errors)
      }
    } catch (err) {
      if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = false
      this.showErrors(`${this.networkErrorTextValue} ${err.message || ""}`.trim())
    }
  }

  showErrors(errors) {
    if (!this.hasErrorAlertTarget) return
    this.errorAlertTarget.classList.remove("hidden")

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

  hideError() {
    if (this.hasErrorAlertTarget) this.errorAlertTarget.classList.add("hidden")
    if (this.hasErrorListTarget) this.errorListTarget.innerHTML = ""
  }
}
