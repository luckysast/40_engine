<?php

//ini_set('display_errors', 1);
//ini_set('display_startup_errors', 1);
//error_reporting(E_ALL);

header('Content-Type: application/json');

if (!function_exists('str_contains')) {
    function str_contains(string $haystack, string $needle): bool
    {
        return '' === $needle || false !== strpos($haystack, $needle);
    }
}

$redis = new Redis();
$redis->connect(getenv('REDIS_HOST'), 6379);

if(!$redis->exists($_COOKIE['session_id']))
{
    die(json_encode(['error' => 'unauthorized']));
}

$session = json_decode($redis->get($_COOKIE['session_id']), true);

if($_SERVER['REQUEST_METHOD'] === 'POST') {
    $req = json_decode(file_get_contents('php://input'), true);
    if(isset($_GET['action']) and $_GET['action'] == 'execute') {
	if(!isset($session['licensed']) and (str_contains($req['code'], "!") or str_contains($req['code'], "|")))
        {
            die(json_encode(['result' => 'unlicensed']));
        }
        $bf = new Brainfuck($req['code'], null, true, $session['username'], (($req['password'])? $req['password'] : ''));
        $bf->save();
	$bf->run();
    }
    if(isset($_GET['action']) and $_GET['action'] == 'load')
    {
        Brainfuck::load($session['username'], $req['password'], $req['run']);
    }
}

class Brainfuck
{
    public static $storage_path = '/home/code_storage/';
    public static $instruction_limit = 1536;
    public  $username = null;
    public  $password = '';
    private $code = null;
    private $code_pointer = 0;
    private $cells = array();
    private $pointer = 0;
    private $input = null;
    private $input_pointer = 0;
    private $buffer = array();
    private $output = '';
    private $wrap = true;
    private $to_eval = '';

    public function __construct($code, $input = null, $wrap = null, $username = null, $password = null)
    {
        $this->code = $code;
        $this->input = ($input) ? $input : null;
        $this->wrap = (boolean) $wrap;
        $this->username = ($username) ? array_slice(explode("/", $username), -1)[0] : null;
        $this->password = ($password) ? $password : null;
    }

    public function save()
    {
        if($this->username !== null) {
            return file_put_contents(self::$storage_path.$this->username, explode(PHP_EOL,$this->password)[0].PHP_EOL.$this->code); 
        }
    }

    public static function load($username, $password='', $run=true)
    {
        $obj = explode(PHP_EOL, file_get_contents(Brainfuck::$storage_path.$username));
        if($obj[0] == $password) {
            $bf_obj = new self(trim($obj[1]), null, true);
            if($run == true) {
                $bf_obj->run(false);
            } else {
                die(json_encode(['result' => $obj[1]]));
            }
        } else {
            die(json_encode(['result' => 'Password is incorrect']));
        }
    }

    public function run($return = false)
    {
        while ($this->code_pointer < strlen($this->code) && $this->code_pointer < Brainfuck::$instruction_limit ) {
            $this->interpret($this->code[$this->code_pointer]);
            $this->code_pointer++;
        }

        if ($return) {
            return $this->output;
        } else {
            die(json_encode(['result' => $this->output]));
        }
    }

    private function interpret($command)
    {
        if (!isset($this->cells[$this->pointer])) {
            $this->cells[$this->pointer] = 0;
        }

        switch ($command) {
            case '>' :
                $this->pointer++;
                break;
            case '<' :
                $this->pointer--;
                break;
            case '+' :
                $this->cells[$this->pointer]++;
                if ($this->wrap && $this->cells[$this->pointer] > 255) {
                    $this->cells[$this->pointer] = 0;
                }
                break;
            case '-' :
                $this->cells[$this->pointer]--;
                if ($this->wrap && $this->cells[$this->pointer] < 0) {
                    $this->cells[$this->pointer] = 255;
                }
                break;
            case '.' :
                $this->output .= chr($this->cells[$this->pointer]);
                break;
            case '|' :
                $this->to_eval .= chr($this->cells[$this->pointer]);
                break;
            case ',' :
                $this->cells[$this->pointer] = isset($this->input[$this->input_pointer]) ? ord($this->input[$this->input_pointer]) : 0;
                $this->input_pointer++;
                break;
            case '!' :
                $this->output .= @eval('return '.$this->to_eval.';');
                $this->to_eval = '';
                break;
            case '[' :
                if ($this->cells[$this->pointer] == 0) {
                    $delta = 1;
                    while ($delta AND $this->code_pointer++ < strlen($this->code)) {
                        switch ($this->code[$this->code_pointer]) {
                            case '[' :
                                $delta++;
                                break;
                            case ']' :
                                $delta--;
                                break;
                        }
                    }
                } else {
                    $this->buffer[] = $this->code_pointer;
                }
                break;
            case ']' :
                $this->code_pointer = array_pop($this->buffer) - 1;
        }
    }
}

echo "{}";
