function genkitPlugin(pluginName, initFn, resolveFn, listActionsFn) {
  return (genkit) => ({
    name: pluginName,
    initializer: async () => {
      await initFn(genkit);
    },
    resolver: async (action, target) => {
      if (resolveFn) {
        return await resolveFn(genkit, action, target);
      }
    },
    listActions: async () => {
      if (listActionsFn) {
        return await listActionsFn();
      }
      return [];
    }
  });
}
export {
  genkitPlugin
};
//# sourceMappingURL=plugin.mjs.map