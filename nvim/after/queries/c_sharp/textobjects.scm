; extends
(method_declaration
  name: (_) @function.name)

(class_declaration
  name: (_) @class.name)
; better function.* that supports arrow functions
(method_declaration
  body: [
    (arrow_expression_clause (_) @function.inner) @function.outer
     (block
       .
       "{"
       .
       (_) @_start @_end
       (_)? @_end
       .
       "}"
       (#make-range! "function.inner" @_start @_end)) @function.outer])
