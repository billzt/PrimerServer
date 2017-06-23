<?php

$config = parse_ini_file("../config.ini", true);

$groups = preg_grep('/^Database\./', array_keys($config));
$database_dir = $config['Path']['database'];

if ($groups) {
    foreach ($groups as $group) {
        $group_name = preg_replace('/^Database\./', '', $group);
?>
<optgroup label="<?php echo $group_name ?>">
<?php
        
        // option name and value
        foreach (array_keys($config[$group]) as $value) {
            $name = $config[$group][$value];
            
            $file = "$database_dir/$value.fai";
            
            // sub text (ID format)
            $id_array = array();
            exec("cut -f 1 $file | grep -i -v 'scaffold' | head -n 50 | sort -V", $id_array);
            $id_start = $id_array[0];
            $id_end = end($id_array);
            
?>
    <option data-subtext=" ID e.g.: <?php echo "$id_start ~ $id_end" ?>" value="<?php echo $value ?>"><?php echo $name ?></option>
<?php
        }
?>
</optgroup>
<?php
    }
}
else {
    foreach (glob("$database_dir/*.fai") as $file) {
        // option name and value
        $value = basename($file, '.fai');
        $name = $value;
        
        // sub text (ID format)
        $id_array = array();
        exec("cut -f 1 $file | grep -i -v 'scaffold' | head -n 50 | sort -V", $id_array);
        $id_start = $id_array[0];
        $id_end = end($id_array);
        
    ?>
    <option data-subtext="<?php echo "$id_start ~ $id_end" ?>" value="<?php echo $value ?>"><?php echo $name ?></option>
    <?php
    }
}
