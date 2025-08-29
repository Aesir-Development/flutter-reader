var pluginMap = {};

function plugin_details(plugin) {
  let _plugin = pluginMap[plugin];
  return _plugin.plugin_details();
}
