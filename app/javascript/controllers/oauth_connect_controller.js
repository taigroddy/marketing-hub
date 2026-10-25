import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    networkErrorText: { type: String, default: "" },
    connectErrorText: { type: String, default: "" }
  }

  get authHeaders() {
    const authToken = document.querySelector('meta[name="auth-token"]')?.content
    const headers = { "Accept": "application/json" }
    if (authToken) {
      headers["Authorization"] = `Bearer ${authToken}`
    }
    return headers
  }

  async connect(event) {
    if (event) event.preventDefault()

    const trigger = event.currentTarget
    const platform = trigger?.dataset?.platform
    if (!platform) return

    try {
      const response = await fetch(`/api/v1/${platform}/oauth/authorize`, {
        headers: this.authHeaders
      })

      const data = await response.json()

      if (response.ok && data.success && data.data?.authorize_url) {
        window.location.href = data.data.authorize_url
      } else {
        alert(data.errors || this.connectErrorTextValue)
      }
    } catch (err) {
      alert(`${this.networkErrorTextValue} ${err.message || ""}`.trim())
    }
  }
}
