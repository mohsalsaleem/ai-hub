class Hash
  def deep_sort
    sort.to_h { |key, value| [ key, value.respond_to?(:deep_sort) ? value.deep_sort : value ] }
  end
end

class Array
  def deep_sort = map { |value| value.respond_to?(:deep_sort) ? value.deep_sort : value }
end
