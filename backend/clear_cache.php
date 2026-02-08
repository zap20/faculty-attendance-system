<?php
// Clear OPcache
if (function_exists('opcache_reset')) {
    opcache_reset();
    echo "OPcache cleared";
} else {
    echo "OPcache not available";
}

// Clear APC cache if available
if (function_exists('apc_clear_cache')) {
    apc_clear_cache();
    echo "APC cache cleared";
}
?>
//