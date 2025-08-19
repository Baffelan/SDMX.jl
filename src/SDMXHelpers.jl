"""
General helper functions for SDMX.jl
"""

export is_url, normalize_sdmx_url, fetch_sdmx_xml

"""
    is_url(input::String) -> Bool

Detect if a string is a URL using robust pattern matching.
Handles various URL formats including:
- http://example.com
- https://example.com  
- www.example.com
- example.com/path
- ftp://example.com
"""
function is_url(input::String)
    @assert !isempty(input) "Input string cannot be empty"
    
    # Convert to lowercase for pattern matching
    lower_input = lowercase(strip(input))
    
    # Pattern 1: Explicit protocol
    if occursin(r"^(https?|ftp)://", lower_input)
        return true
    end
    
    # Pattern 2: Starts with www.
    if occursin(r"^www\.", lower_input)
        return true
    end
    
    # Pattern 3: Domain-like pattern (has dot and looks like domain)
    # Must have at least one dot, and not look like XML content
    if occursin(r"^[a-zA-Z0-9][a-zA-Z0-9\-]*\.[a-zA-Z0-9\-\.]+(/.*)?$", lower_input) && 
       !occursin("<", input)  # Exclude XML content
        return true
    end
    
    return false
end

"""
    normalize_sdmx_url(url::String) -> String

Normalize a URL to ensure it has proper protocol and SDMX references=all parameter.
- Adds https:// if no protocol is specified
- Adds references=all parameter if not already present
- Handles existing query parameters correctly
"""
function normalize_sdmx_url(url::String)
    @assert !isempty(url) "URL cannot be empty"
    @assert is_url(url) "Input must be a valid URL"
    
    normalized_url = strip(url)
    
    # Add protocol if missing
    if !occursin(r"^(https?|ftp)://", lowercase(normalized_url))
        if startswith(lowercase(normalized_url), "ftp")
            normalized_url = "ftp://" * normalized_url
        else
            normalized_url = "https://" * normalized_url
        end
    end
    
    # Check if references=all parameter is already present
    if occursin(r"[?&]references=all", lowercase(normalized_url))
        return normalized_url  # Already has the parameter
    end
    
    # Add references=all parameter
    if occursin("?", normalized_url)
        # URL already has query parameters
        normalized_url *= "&references=all"
    else
        # Add query parameters
        normalized_url *= "?references=all"
    end
    
    return normalized_url
end

"""
    fetch_sdmx_xml(input::String) -> String

Fetch SDMX XML content from a URL or return XML string as-is.
Automatically handles URL normalization and validation.
"""
function fetch_sdmx_xml(input::String)
    @assert !isempty(input) "Input cannot be empty"
    
    if is_url(input)
        # It's a URL - normalize and fetch
        normalized_url = normalize_sdmx_url(input)
        
        response = HTTP.get(normalized_url)
        @assert response.status == 200 "HTTP request failed with status: $(response.status) for URL: $normalized_url"
        
        xml_string = String(response.body)
        @assert !isempty(xml_string) "HTTP response body cannot be empty"
        
        return xml_string
    else
        # It's XML content - validate and return
        @assert occursin("<", input) "Input doesn't appear to be valid XML or URL"
        return input
    end
end 