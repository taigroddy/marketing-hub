import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["errorAlert", "errorMsg", "submitBtn", "emailInput", "passwordInput"]
  static values = {
    failedText: { type: String, default: "" },
    networkErrorText: { type: String, default: "" },
    dashboardUrl: { type: String, default: "" }
  }

  async submit(event) {
    if (event) event.preventDefault()

    this.hideError()
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
    }

    const payload = {
      email: this.hasEmailInputTarget ? this.emailInputTarget.value.trim() : "",
      password: this.hasPasswordInputTarget ? this.passwordInputTarget.value : ""
    }

    try {
      const response = await fetch("/api/v1/auth/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify(payload)
      })

      const data = await response.json()

      if (response.ok && data.success) {
        const token = data.data.token
        const refreshToken = data.data.refresh_token
        const isSecure = window.location.protocol === "https:" ? "; Secure" : ""

        document.cookie = `jwt_token=${token}; path=/; max-age=3600; SameSite=Lax${isSecure}`
        if (refreshToken) {
          document.cookie = `refresh_token=${refreshToken}; path=/; max-age=2592000; SameSite=Lax${isSecure}`
        }
        window.location.href = this.dashboardUrlValue || "/dashboard"
      } else {
        if (this.hasSubmitBtnTarget) {
          this.submitBtnTarget.disabled = false
        }
        const err = data.errors || this.failedTextValue
        const message = typeof err === "object" ? Object.values(err).flat().join(", ") : String(err)
        this.showError(message)
      }
    } catch (err) {
      if (this.hasSubmitBtnTarget) {
        this.submitBtnTarget.disabled = false
      }
      this.showError(`${this.networkErrorTextValue} ${err.message || ""}`.trim())
    }
  }

  showError(msg) {
    if (this.hasErrorAlertTarget && this.hasErrorMsgTarget) {
      this.errorMsgTarget.textContent = msg
      this.errorAlertTarget.classList.remove("hidden")
    }
  }

  hideError() {
    if (this.hasErrorAlertTarget && this.hasErrorMsgTarget) {
      this.errorAlertTarget.classList.add("hidden")
      this.errorMsgTarget.textContent = ""
    }
  }
}
