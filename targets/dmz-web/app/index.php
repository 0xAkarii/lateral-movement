<?php
/**
 * Vulnerable Network Diagnostic Tool
 *
 * !!! INTENTIONALLY VULNERABLE - FOR LAB DEMO ONLY !!!
 *
 * Vulnerability: Command injection via 'host' parameter
 * Attack vector: ?host=8.8.8.8;id  or  ?host=8.8.8.8|whoami
 */
?>
<!DOCTYPE html>
<html>
<head>
    <title>Acme Corp - Network Diagnostic Tool</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f0f0f0; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        input[type="text"] { width: 60%; padding: 10px; font-size: 16px; }
        button { padding: 10px 20px; background: #007bff; color: white; border: none; cursor: pointer; }
        pre { background: #1e1e1e; color: #00ff00; padding: 15px; border-radius: 4px; overflow-x: auto; }
        .footer { margin-top: 30px; color: #888; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Network Diagnostic Tool v1.2</h1>
        <p>Internal tool untuk operations team. Cek konektivitas ke server.</p>

        <form method="GET" action="">
            <input type="text" name="host" placeholder="Enter hostname or IP" value="<?php echo isset($_GET['host']) ? htmlspecialchars($_GET['host']) : '8.8.8.8'; ?>">
            <button type="submit">Ping</button>
        </form>

        <?php
        if (isset($_GET['host'])) {
            $host = $_GET['host'];

            // !!! VULNERABLE: No input sanitization !!!
            // Direct command injection via shell_exec
            echo "<h3>Ping result for: " . htmlspecialchars($host) . "</h3>";
            echo "<pre>";
            $output = shell_exec("ping -c 2 " . $host . " 2>&1");
            echo htmlspecialchars($output);
            echo "</pre>";
        }
        ?>

        <div class="footer">
            <p>Acme Corp Internal Tool | Version 1.2 | Last updated: 2024-01</p>
            <p>Contact: ops@acme.corp | Maintenance window: Sundays 02:00 UTC</p>
            <!-- TODO: remove this comment before production
                 Maintenance access: webapp@internal-app via SSH key in /var/www/html/.maintenance_key
            -->
        </div>
    </div>
</body>
</html>
