
/*
 *= require action_cable/connection
 *= require action_cable/connection_monitor
 *= require action_cable/subscriptions
 *= require action_cable/subscription
 */

(function() {
  ActionCable.Consumer = (function() {
    function Consumer(url) {
      this.url = url;
      this.subscriptions = new ActionCable.Subscriptions(this);
      this.connection = new ActionCable.Connection(this);
      this.connectionMonitor = new ActionCable.ConnectionMonitor(this);
    }

    Consumer.prototype.send = function(data) {
      return this.connection.send(data);
    };

    return Consumer;

  })();

}).call(this);
