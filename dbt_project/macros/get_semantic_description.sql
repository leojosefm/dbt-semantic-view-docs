{#
  get_semantic_description(model_name, column_name)

  Returns the already-resolved dbt description of a model column as a
  single-quoted, SQL-safe string literal (apostrophes escaped).
  Returns '' when the column is undocumented or not found.

  Assumes model names are unique. In multi-package projects, also match on
  node.package_name or node.unique_id.
#}
{% macro get_semantic_description(model_name, column_name) %}

    {# namespace() is required: a plain `set` inside a for-loop does not persist #}
    {% set ns = namespace(description='') %}

    {% for node in graph.nodes.values() %}
        {% if node.resource_type == 'model' and node.name == model_name %}
            {% if column_name in node.columns %}
                {% set ns.description = node.columns[column_name].description %}
            {% endif %}
        {% endif %}
    {% endfor %}

    {{ return("'" ~ (ns.description | default('', true) | trim | replace("'", "''")) ~ "'") }}

{% endmacro %}
