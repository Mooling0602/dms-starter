paths:
builtins.concatMap (
  p:
  if builtins.pathExists p then
    [ p ]
  else
    builtins.warn "optionalImports: skipping non-existent path ${toString p}" [ ]
) paths
