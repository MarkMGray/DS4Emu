import time
import random
from python_imagesearch.imagesearch import imagesearch, imagesearch_numLoop
import pyautogui
from pyautogui import keyDown, keyUp, moveTo, position
import cv2
from pynput import keyboard

pyautogui.FAILSAFE = True # Move mouse to top left to stop PyAutoGui

step = 0
images = list(range(1,9))

def parse_script(fileName):
	file = open(fileName, 'r')
	lines = file.readlines()
	actions = []
	for line in lines:
		arr = line.split('#')[0].strip('\n').split(',')
		if len(arr) <= 1:
			break
		actions.append({ 'key': arr[0], 'value': arr[1] })
	return actions

home_actions = parse_script('scripts/home_script.txt')
plant_1_actions = parse_script('scripts/plant_1.txt')
plant_2_actions = parse_script('scripts/plant_2.txt')
plant_3_actions = parse_script('scripts/plant_3.txt')

walk_directions = [ 'w', 'a', 's', 'd']

# What does bot need to do
'''

 1 Able to load scripts into memory for execution (happy path)
 2 Determine if lost and try to recover
 3 Attempt to recover based on
	- What image we are looking for
	- Random walk
 4 Reset when completely lost (in-field only)
	- if we are running in field and lost and unrecoverable
	- open menu
	- teleport to home base
	- turn camera back and start over
 5 determine when sequence is complete and start over

 BONUS:
	- Overlay on screen of metrics
	- Overlay of setp
	- Overlay of # gems gathered etc
'''

class Bot:
	def __init__(self):
		self.scripts = {}
		self.lost = False # are we lost yet?
	def addScript(self, name, script, resetScript):
		self.scripts[name] = { script, resetScript }
		print(self.scripts[name])

	def executeScript(self, name):
		script = self.scripts[name].script
		if (script == None):
			print(f'No script found for {name} - make sure you loaded it')
			raise ReferenceError()
		for action in self.script:
			print(action['key'], action['value'])
			key = action['key']
			value = action['value']
			if key == 'find': # find an image in screen or we are lost!
				findImageOrLost(value)
			else:
				duration = int(value)
				pressKey(direction_key, duration)
			
			if self.lost: # handle if we get lost searching for an image
				print('I dont know where to go man')
				attemptToRecoverFromLost(key, value)
	
	def attemptToRecoverFromLost(self, action, value):
		if action != 'find':
			print('We cant be lost if we are not searching for something')
			self.lost = False
			return
		
		print('We are attempting to recover by performing a rando walk of 30 steps')
		i = 0
		while i < 30:
			pos = imagesearch_numLoop(value, 0.25, 5, 0.5)
			if pos[0] == -1: # step
				print('stepping')
				direction_key = walk_directions[random.randint(0, len(walk_directions) - 1)]
				duration = random.randint(200, 350)
				pressKey(direction_key, duration)
			else:
				self.lost = false
				return
			i+=1
		# if we never find what we are looking for we should reset if possible
		if self.lost:
			attemptReset()

	def attemptReset(self):
		print('We are definitely lost, we should reset and staart the script over')

	def findImageOrLost(self, imageName): # image search for the image name and if we find it keep going else we are lost!
		filePath = f'./frozen_flora_bot_phots/{imageName}'
		pos = imagesearch_numLoop(filePath, 1, 20, 0.55)
		if (pos[0] != -1):
			print('We found it - ', pos[0], pos[1])
		else:
			print('WE ARE LOST!!!')
			self.lost = True
	
	def pressKey(self, key, duration):
		print(f'Pressing {key} for {duration}ms')
		keyDown(key)
		time.sleep(duration/1000)
		keyUp(key)

floraBot = Bot()
floraBot.addScript('home', home_actions)
floraBot.addScript('plant1', plant_1_actions)
floraBot.addScript('plant2', plant_2_actions)
floraBot.addScript('plant3', plant_3_actions)

# run until ESC is pressed
break_program = False
start_bot = False
pause_bot = False

def on_press(key):
	global break_program
	global start_bot
	print(key)
	if (key == keyboard.Key.Escape):
		print('ESC pressed - EXITING')
		break_program = True
		return false
	if (key == keyboard.from_char('1')):
		print('1 Pressed - STARTING BOT')
		start_bot = True
	if (key == keyboard.from_char('=')):
		print('= Pressed', if pause_bot 'Un-Pausing' else 'Pausing')
		pause_bot = not pause_bot

def check_pause():
	while pause_bot == True:
		print('Bot paused - please un-pause with =')
		time.sleep(2)

with keyboard.Listener(on_press=on_press) as listener:
	while break_program == False:
		# run bot
		while start_bot == False:
			print('Bot initialized - waiting to start')
			time.sleep(5)
		
		print('Bot starting!')

		# Must be started in the home area
		check_pause()
		bot.executeScript('home')
		time.sleep(45) # sleep for the duration of the loading screen

		check_pause()
		bot.executeScript('plant1')
		time.sleep(2)

		check_pause()
		bot.executeScript('plant2')

		check_pause()
		bot.executeScript('plant3')
		time.sleep(45) # sleep time for loading screens

		print('Bot loop complete, starting over')
	listener.join()