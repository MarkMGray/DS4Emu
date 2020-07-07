import time
from python_imagesearch.imagesearch import imagesearch, imagesearch_numLoop
import pyautogui
from pyautogui import keyDown, keyUp, moveTo, position
import cv2

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
		actions.append({ 'key': arr[0], 'duration': arr[1] })
	return actions

home_actions = parse_script('scripts/home_script.txt')
plant_1_actions = parse_script('scripts/plant_1.txt')
plant_2_actions = parse_script('scripts/plant_2.txt')
plant_3_actions = parse_script('scripts/plant_3.txt')
print(home_actions)


class Bot:
	def __init__(self, steps):
		self.steps = steps
	def setScript(self, script):
		self.script = script

	def executeScript(self):
		for action in self.script:
			print(action['key'], action['duration'])
			key = action['key']
			duration = int(action['duration'])
			if (key != 'mouseLeft' or key != 'mouseRight'):
				print('executing - ', key)
				keyDown(key)
				time.sleep(duration/1000)
				keyUp(key)
			if (key == 'mouseLeft'):
				info = position()
				moveTo(info.x - duration, info.y, 0.25)
				time.sleep(0.5)
			if (key == 'mouseRight'):
				info = position()
				print(info.y)
				print(duration)
				print(info.y - duration)
				moveTo(x=info.x + duration, y=info.y, duration=0.25)
				time.sleep(0.5)

	def execute(self):
		for step in self.steps:
			step.execute()

class Step:
	def __init__(self, imageName, actions):
		self.imageName = imageName
		self.actions = actions

	def execute(self):
		time.sleep(1)
		image = f'./frozen_flora_bot_phots/{self.imageName}'
		pos = imagesearch_numLoop(image, 1, 10, 0.4)
		if (pos[0] != -1):
			for action in self.actions:
				action.execute()
				time.sleep(0.2)
		else:
			print('we cant find the image - HELP!')

class Action:
	def __init__(self, key, durationMS):
		self.key = key
		self.duration = durationMS

	def execute(self):
		print('executing ', self.key)
		keyDown(self.key)
		time.sleep(self.duration / 1000)
		keyUp(self.key)

# pos = imagesearch("./frozen_flora_bot_phots/4.png", 0.4)
# if (pos[0] != -1):
# 	print("position: ", pos[0], pos[1])
# 	moveTo(pos[1], pos[0], 0.25)
# else:
#	print("image not found")

print(pyautogui.size())
CircleAction = Action('c', 150)
XAction = Action('space', 150)
UpAction = Action('up', 150)
DownAction = Action('down', 25)
WalkForward = Action('w', 500)
WalkRight = Action('d', 500)
WalkBack = Action('s', 500)
LongSleep = Action('-', 20000)


# ----- Part 1 - Accepting the quest -----------
loadInStep = Step('1.png', [WalkForward, WalkForward, WalkForward, WalkRight, WalkRight, WalkRight, WalkRight, WalkBack])
openQuestBoard = Step('2.png', [XAction])
questsLoaded = Step('4.png', [XAction])
listQuests = Step('6.png', [DownAction, DownAction, DownAction, XAction])
listEventQuests = Step('8.png', [DownAction, DownAction, XAction])
selectQuest = Step('9.png', [XAction])
selectStartLoc = Step('10.png', [DownAction, DownAction, XAction])
acceptQuest = Step('11.png', [XAction, LongSleep, LongSleep]) # todo make these smarter some how
departOnQuest = Step('12.png', [DownAction, XAction])
readyToGo = Step('13.png', [XAction])

# ------- Part 2 - Completing the quest ----------
# todo add a long sleep action for loading screen

#loadInStep
floraBot = Bot([ loadInStep, openQuestBoard,
questsLoaded, listQuests, listEventQuests, selectQuest,
selectStartLoc, acceptQuest, departOnQuest, readyToGo])

time.sleep(1)
floraBot.setScript(plant_1_actions)
time.sleep(4)
floraBot.executeScript()
# floraBot.execute()