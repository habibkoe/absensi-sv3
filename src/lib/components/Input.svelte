<script lang="ts">
    export let value: string | number = "";
    export let type:
        | "text"
        | "email"
        | "password"
        | "number"
        | "date"
        | "tel"
        | "url"
        | "search" = "text";
    export let label: string = "";
    export let id: string = `input-${Math.random().toString(36).substring(2, 9)}`;
    export let placeholder: string = "";
    export let required: boolean = false;
    export let disabled: boolean = false;
    export let readonly: boolean = false;
    export let error: string = "";

    let className = "";
    export { className as class };

    // Base styles
    const baseClasses =
        "w-full px-4 py-2 border rounded-lg focus:ring-2 focus:outline-none transition-colors duration-200 disabled:bg-gray-100 disabled:text-gray-500 disabled:cursor-not-allowed";

    // State-dependent styles
    $: stateClasses = error
        ? "border-red-300 focus:border-transparent focus:ring-red-500 bg-red-50 text-red-900 placeholder-red-300"
        : "border-gray-300 focus:border-transparent focus:ring-blue-500 bg-white text-gray-900 placeholder-gray-400";

    $: classes = `${baseClasses} ${stateClasses} ${className}`;
</script>

<div class="w-full">
    {#if label}
        <label
            for={id}
            class="block mb-2 text-sm font-medium {error
                ? 'text-red-700'
                : 'text-gray-700'}"
        >
            {label}
            {required ? "*" : ""}
        </label>
    {/if}

    <input
        {id}
        {type}
        bind:value
        {placeholder}
        {required}
        {disabled}
        {readonly}
        class={classes}
        on:input
        on:change
        on:focus
        on:blur
        {...$$restProps}
    />

    {#if error}
        <p class="mt-1 text-sm text-red-600 animate-fadeIn">
            {error}
        </p>
    {/if}
</div>

<style>
    /* Simple fade-in animation for error message */
    @keyframes fadeIn {
        from {
            opacity: 0;
            transform: translateY(-4px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    .animate-fadeIn {
        animation: fadeIn 0.2s ease-out forwards;
    }
</style>
