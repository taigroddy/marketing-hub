import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "success", "error", "errorMsg"]
  static values = {
    token: { type: String, default: "" },
    networkErrorText: { type: String, default: "" },
    errorMsgText: { type: String, default: "" },
    dashboardUrl: { type: String, default: "" }
  }

  connect() {
    if (this.started) return
    this.started = true
    this.performConfirmation()
  }

  async performConfirmation() {
    const token = this.tokenValue

    if (!token) {
      this.showError(this.errorMsgTextValue)
      return
    }

    try {
      const response = await fetch(`/api/v1/auth/confirm_email/${encodeURIComponent(token)}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json"
        }
      })

      const data = await response.json()

      if (response.ok && data.success) {
        if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
        if (this.hasSuccessTarget) this.successTarget.classList.remove("hidden")

        const jwtToken = data.data?.token
        if (jwtToken) {
          const isSecure = window.location.protocol === "https:" ? "; Secure" : ""
          document.cookie = `jwt_token=${jwtToken}; path=/; max-age=3600; SameSite=Lax${isSecure}`
        }

        setTimeout(() => {
          window.location.href = this.dashboardUrlValue || "/dashboard"
        }, 800)
      } else {
        const err = data.errors || this.errorMsgTextValue
        const message = typeof err === "object" ? Object.values(err).flat().join(", ") : String(err)
        this.showError(message)
      }
    } catch (err) {
      this.showError(`${this.networkErrorTextValue} ${err.message || ""}`.trim())
    }
  }

  showError(msg) {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
    if (this.hasErrorTarget) this.errorTarget.classList.remove("hidden")
    if (this.hasErrorMsgTarget) this.errorMsgTarget.textContent = msg
  }
}
