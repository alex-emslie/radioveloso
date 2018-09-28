import { Consumer } from "./consumer"

let defaultExport = {}
defaultExport.ActionCable = {
  WebSocket: window.WebSocket,
  logger: window.console,

  createConsumer(url) {
    if (url == null) { let left
    url = (left = this.getConfig("url")) != null ? left : this.INTERNAL.default_mount_path }
    return new Consumer(this.createWebSocketURL(url))
  },

  getConfig(name) {
    const element = document.head.querySelector(`meta[name='action-cable-${name}']`)
    return (element != null ? element.getAttribute("content") : undefined)
  },

  createWebSocketURL(url) {
    if (url && !/^wss?:/i.test(url)) {
      const a = document.createElement("a")
      a.href = url
      // Fix populating Location properties in IE. Otherwise, protocol will be blank.
      a.href = a.href
      a.protocol = a.protocol.replace("http", "ws")
      return a.href
    } else {
      return url
    }
  },

  startDebugging() {
    return this.debugging = true
  },

  stopDebugging() {
    return this.debugging = null
  },

  log(...messages) {
    if (this.debugging) {
      messages.push(Date.now())
      return this.logger.log("[ActionCable]", ...Array.from(messages))
    }
  }
}
export default defaultExport
