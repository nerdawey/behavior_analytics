# frozen_string_literal: true

module BehaviorAnalytics
  module Javascript
    class Client
      def self.generate_script(tracker_url: "/behavior_analytics/track", auto_track: true)
        <<~JAVASCRIPT
          (function() {
            var BehaviorAnalytics = {
              trackerUrl: '#{tracker_url}',
              visitorToken: null,
              visitToken: null,
              
              init: function() {
                this.loadVisitorToken();
                #{'this.autoTrack();' if auto_track}
              },
              
              loadVisitorToken: function() {
                var token = this.getCookie('behavior_visitor_token');
                if (!token) {
                  token = this.generateToken();
                  this.setCookie('behavior_visitor_token', token, 730); // 2 years
                }
                this.visitorToken = token;
              },
              
              generateToken: function() {
                return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                  var r = Math.random() * 16 | 0;
                  var v = c == 'x' ? r : (r & 0x3 | 0x8);
                  return v.toString(16);
                });
              },
              
              setCookie: function(name, value, days) {
                var expires = '';
                if (days) {
                  var date = new Date();
                  date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
                  expires = '; expires=' + date.toUTCString();
                }
                document.cookie = name + '=' + (value || '') + expires + '; path=/; SameSite=Lax';
              },
              
              getCookie: function(name) {
                var nameEQ = name + '=';
                var ca = document.cookie.split(';');
                for (var i = 0; i < ca.length; i++) {
                  var c = ca[i];
                  while (c.charAt(0) == ' ') c = c.substring(1, c.length);
                  if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
                }
                return null;
              },
              
              track: function(eventName, properties) {
                var payload = {
                  event_name: eventName,
                  properties: properties || {},
                  visitor_token: this.visitorToken,
                  visit_token: this.visitToken,
                  page: window.location.pathname,
                  referrer: document.referrer,
                  user_agent: navigator.userAgent,
                  timestamp: new Date().toISOString()
                };
                
                this.sendRequest(payload);
              },
              
              trackPageView: function() {
                this.track('page_view', {
                  path: window.location.pathname,
                  title: document.title,
                  referrer: document.referrer
                });
              },
              
              trackClick: function(element, properties) {
                var props = {
                  element: element.tagName.toLowerCase(),
                  id: element.id || null,
                  class: element.className || null,
                  text: element.textContent ? element.textContent.substring(0, 100) : null
                };
                
                if (properties) {
                  Object.assign(props, properties);
                }
                
                this.track('click', props);
              },
              
              autoTrack: function() {
                var self = this;
                
                // Track page view on load
                if (document.readyState === 'loading') {
                  document.addEventListener('DOMContentLoaded', function() {
                    self.trackPageView();
                  });
                } else {
                  this.trackPageView();
                }
                
                // Track clicks on elements with data-track attribute
                document.addEventListener('click', function(e) {
                  var element = e.target;
                  if (element.hasAttribute('data-track')) {
                    var trackValue = element.getAttribute('data-track');
                    var properties = {};
                    
                    if (element.hasAttribute('data-track-properties')) {
                      try {
                        properties = JSON.parse(element.getAttribute('data-track-properties'));
                      } catch (e) {}
                    }
                    
                    self.track(trackValue || 'click', properties);
                  }
                });
                
                // Track form submissions
                document.addEventListener('submit', function(e) {
                  var form = e.target;
                  if (form.tagName === 'FORM' && form.hasAttribute('data-track')) {
                    var trackValue = form.getAttribute('data-track');
                    self.track(trackValue || 'form_submit', {
                      form_id: form.id || null,
                      form_action: form.action || null
                    });
                  }
                });
              },
              
              sendRequest: function(payload) {
                if (navigator.sendBeacon) {
                  var blob = new Blob([JSON.stringify(payload)], { type: 'application/json' });
                  navigator.sendBeacon(this.trackerUrl, blob);
                } else {
                  var xhr = new XMLHttpRequest();
                  xhr.open('POST', this.trackerUrl, true);
                  xhr.setRequestHeader('Content-Type', 'application/json');
                  xhr.send(JSON.stringify(payload));
                }
              }
            };
            
            // Initialize on load
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', function() {
                BehaviorAnalytics.init();
              });
            } else {
              BehaviorAnalytics.init();
            }
            
            // Expose globally
            window.BehaviorAnalytics = BehaviorAnalytics;
          })();
        JAVASCRIPT
      end
    end
  end
end

